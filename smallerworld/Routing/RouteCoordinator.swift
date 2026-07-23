import HotwireNative
import SafariServices
import UIKit
import WebKit
import os

/// Owns the `Navigator` and the incremental routing state machine that walks
/// the nav stack toward a pending `targetURL`. Also serves as the hub for the
/// three delegates that feed navigation: Hotwire's `NavigatorDelegate`, the QR
/// scanner, and notification interactions (see the `RouteCoordinator+…`
/// extension files).
///
/// `SceneDelegate` keeps only scene-lifecycle duties and forwards incoming
/// URLs (deep links, universal links, notifications) here.
///
/// A handful of members below are `internal` rather than `private` only so the
/// delegate conformances in the sibling extension files can reach them —
/// `private` is file-scoped in Swift and would not cross those file boundaries.
final class RouteCoordinator: NSObject {
    var targetURL: URL?
    var lastErroredURL: URL?
    let launchOverlay = LaunchOverlay()
    private lazy var navigator = Navigator(
        configuration: .init(
            name: "main",
            startLocation: SmallerWorld.homeURL
        ),
        delegate: self,
    )

    // MARK: Scene interface

    /// The navigator's root view controller, installed as the window's root.
    var rootViewController: UIViewController {
        navigator.rootViewController
    }

    func installLaunchOverlay(over window: UIWindow) {
        launchOverlay.install(over: window)
    }

    func start() {
        navigator.start()
    }

    /// Records the initial route target from a cold start, without routing —
    /// routing kicks off once the first page finishes in `requestDidFinish`.
    func prepareColdStart(_ connectionOptions: UIScene.ConnectionOptions) {
        if let userActivity = connectionOptions.userActivities.first,
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL
        {
            targetURL = SmallerWorld.canonicalURL(for: incomingURL)
            Log.routing.debug(
                "Cold start from universal link: \(incomingURL.absoluteString, privacy: .public)"
            )
        } else if let response = connectionOptions.notificationResponse,
            let incomingURL = notificationTargetURL(response.notification)
        {
            targetURL = incomingURL
            Log.routing.debug(
                "Cold start from notification tap with target: \(incomingURL.absoluteString, privacy: .public)"
            )
        } else {
            Log.routing.debug("Cold start with no deep link; opening at home")
        }
    }

    /// Handles a universal link delivered while the app is already running.
    func continueUserActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL
        else {
            return
        }
        targetURL = SmallerWorld.canonicalURL(for: incomingURL)
        routeTowardsTargetURL()
    }

    // MARK: Routing

    // Does an incremental route towards the target URL.
    //
    // `currentURL` overrides `navigator.activeWebView.url` when provided. Pass
    // it in from `requestDidFinish(at:)` — `activeWebView.url` reflects the
    // page that's currently *painted*, but `requestDidFinish` fires between
    // Turbo's `visitRequestFinished` and `visitRendered`, so the on-screen URL
    // lags the logical position by ~one render cycle. Reading it during that
    // window causes us to keep re-picking the same intermediate hop and burn
    // cancelled visits until it catches up. See docs/hotwire-native-ios.md.
    func routeTowardsTargetURL(currentURL overrideCurrentURL: URL? = nil) {
        guard let targetURL else { return }

        // Present SFSafariViewController if targetURL is external.
        if !SmallerWorld.isAppURL(targetURL) {
            self.targetURL = nil
            let safariViewController = SFSafariViewController(url: targetURL)
            safariViewController.dismissButtonStyle = .close
            navigator.rootViewController.present(safariViewController, animated: true)
            return
        }

        // Clear targetURL if it is the currently active URL.
        let currentURL = overrideCurrentURL ?? navigator.activeWebView.url
        if currentURL == targetURL {
            self.targetURL = nil
            navigator.reload()
            return
        }

        // If `next` is already on the navigation stack, pop to it (animated) and
        // resume routing from the completion block. The match is intentionally
        // query-insensitive — `.path()` strips query/fragment — so a controller
        // showing `/foo?a=1` still matches a target of `/foo?a=2`.
        let nextURL = RouteResolver.nextURL(from: currentURL, to: targetURL)
        let rootVC = navigator.rootViewController
        if let targetVC = rootVC.viewControllers.last(where: { vc in
            guard let visitable = vc as? Visitable else { return false }
            return visitable.currentVisitableURL.path() == nextURL.path()
        }), targetVC !== rootVC.topViewController {
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                guard let self, let targetURL = self.targetURL else { return }
                if nextURL.path() == targetURL.path() {
                    // We popped to this controller by path only, ignoring query
                    // params. Now that it's on top, replace-visit the fully
                    // qualified targetURL so the page reflects the updated query
                    // params — a plain reload() would refetch its stale query.
                    self.targetURL = nil
                    navigator.route(targetURL, options: VisitOptions(action: .replace))
                } else {
                    routeTowardsTargetURL()
                }
            }
            rootVC.popToViewController(targetVC, animated: true)
            CATransaction.commit()
            return
        }

        Log.routing.debug(
            "Routing from \(currentURL?.absoluteString ?? "(nil)", privacy: .public) toward \(targetURL.absoluteString, privacy: .public); next hop is \(nextURL.absoluteString, privacy: .public)"
        )
        if nextURL == targetURL {
            self.targetURL = nil
        }
        // When `nextURL` differs from the current page only by query/fragment
        // (same path), replace the current view controller's content in place
        // instead of pushing a duplicate. `RouteResolver.nextURL` only returns a
        // same-path URL in its equal-segments branch, so this is exactly the
        // query-only-change case — normal forward/back hops return a different
        // path and fall through to the default advancing route below.
        if let currentURL, nextURL.path() == currentURL.path() {
            navigator.route(nextURL, options: VisitOptions(action: .replace))
        } else {
            navigator.route(nextURL)
        }
    }

    // MARK: URL resolution

    /// Extracts the `target_url` deep link from a notification's payload.
    func notificationTargetURL(_ notification: UNNotification) -> URL? {
        let userInfo = notification.request.content.userInfo
        guard let targetString = userInfo["target_url"] as? String else {
            return nil
        }
        return URL(string: targetString, relativeTo: SmallerWorld.baseURL)
    }
}
