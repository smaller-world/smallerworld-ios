import CodeScanner
import HotwireNative
import SafariServices
import UIKit
import WebKit
import os.log

class SceneController: UIResponder {
    var window: UIWindow?

    private var targetURL: URL?
    private var lastErroredURL: URL?
    private let launchOverlay = LaunchOverlay()
    private lazy var navigator = Navigator(
        configuration: .init(
            name: "main",
            startLocation: SmallerWorld.homeURL
        ),
        delegate: self,
    )

    // MARK: Debugging

    private static func trace(_ name: String, _ arguments: [String: Any] = [:]) {
        logger.debug("[SceneController] \(name) \(arguments)")
    }

    private func trace(_ name: String, _ arguments: [String: Any] = [:]) {
        Self.trace(name, arguments)
    }

    // MARK: Routing

    private func route(_ url: URL, options: VisitOptions? = nil) {
        if let currentURL = navigator.activeWebView.url, currentURL == url {
            return
        }
        navigator.route(url, options: options)
    }

    private func promptForAuthentication() {
        let loginURL = SmallerWorld.baseURL.appendingPathComponent("/sessions/new")
        route(loginURL)
    }

    /// Returns the cumulative path at each routable depth along `url`,
    /// skipping any depth whose cumulative path is marked `"unroutable": true`
    /// in the path configuration. `nil` and any URL whose path resolves to
    /// `"presentation": "replace_root"` (e.g. `/home`, `/session/new`) both
    /// return `[]` — these collapse to the nav root.
    ///
    /// Examples (with `/worlds` and `/world_key_grants` marked unroutable):
    /// - nil                            => []
    /// - /home                          => []
    /// - /worlds/asdf-12-23             => ["/worlds/asdf-12-23"]
    /// - /worlds/asdf-12-23/keys        => ["/worlds/asdf-12-23", "/worlds/asdf-12-23/keys"]
    /// - /world_key_grants/TOKEN        => ["/world_key_grants/TOKEN"]
    /// - /worlds                        => ["/worlds"] (unroutable but nowhere to escalate to)
    static func routeSegments(of url: URL?) -> [String] {
        guard let url else { return [] }
        if isRootPath(url) { return [] }
        let raw = url.pathComponents.filter { $0 != "/" }
        var result: [String] = []
        var current = ""
        for component in raw {
            current += "/" + component
            if !isUnroutablePath(current) {
                result.append(current)
            }
        }
        // Fall back to the raw path when every depth was unroutable — callers
        // still need something to land on.
        if result.isEmpty, !current.isEmpty {
            result.append(current)
        }
        return result
    }

    private static func isUnroutablePath(_ path: String) -> Bool {
        let properties = Hotwire.config.pathConfiguration.properties(for: path)
        let unroutable = properties["unroutable"] as? Bool ?? false
        trace("isUnroutable", ["path": path, "unroutable": unroutable])
        return unroutable
    }

    private static func isRootPath(_ url: URL) -> Bool {
        let properties = Hotwire.config.pathConfiguration.properties(for: url)
        return properties["presentation"] as? String == "replace_root"
    }

    /// Returns the next URL to land on while routing from `from` toward `to`.
    /// The caller decides whether to push or pop based on whether the returned
    /// URL is already present in the navigation stack.
    ///
    /// Examples (with /home as root, /worlds unroutable):
    /// - from: /worlds/jordana        to: /home                => /home
    /// - from: /worlds/jordana        to: /worlds/freddy       => /home
    /// - from: /worlds/jordana/keys   to: /worlds/jordana      => /worlds/jordana
    /// - from: /home                  to: /worlds/jordana      => /worlds/jordana
    /// - from: /worlds/freddy         to: /worlds/freddy/keys  => /worlds/freddy/keys
    static func nextRouteURL(from: URL?, to: URL) -> URL {
        let fromSegs = routeSegments(of: from)
        let toSegs = routeSegments(of: to)

        var prefixCount = 0
        let maxPrefix = min(fromSegs.count, toSegs.count)
        while prefixCount < maxPrefix && fromSegs[prefixCount] == toSegs[prefixCount] {
            prefixCount += 1
        }

        if prefixCount == fromSegs.count {
            // Advancing toward `to` (or already there).
            if prefixCount == toSegs.count { return to }
            return SmallerWorld.url(forPath: toSegs[prefixCount])
        }

        // Retreating to the deepest shared ancestor.
        if prefixCount == 0 {
            return SmallerWorld.homeURL
        }

        return SmallerWorld.url(forPath: toSegs[prefixCount - 1])
    }

    // Does an incremental route towards the target URL.
    //
    // `currentURL` overrides `navigator.activeWebView.url` when provided. Pass
    // it in from `requestDidFinish(at:)` — `activeWebView.url` reflects the
    // page that's currently *painted*, but `requestDidFinish` fires between
    // Turbo's `visitRequestFinished` and `visitRendered`, so the on-screen URL
    // lags the logical position by ~one render cycle. Reading it during that
    // window causes us to keep re-picking the same intermediate hop and burn
    // cancelled visits until it catches up. See docs/hotwire-native-ios.md.
    private func routeTowardsTargetURL(currentURL overrideCurrentURL: URL? = nil) {
        guard let targetURL else { return }

        // Present SFSafariViewController if targetURL is external.
        if !SmallerWorld.isAppURL(targetURL) {
            let safariViewController = SFSafariViewController(url: targetURL)
            safariViewController.dismissButtonStyle = .close
            navigator.rootViewController.present(safariViewController, animated: true)
            self.targetURL = nil
            return
        }

        // Clear targetURL if it is the currently active URL.
        let currentURL = overrideCurrentURL ?? navigator.activeWebView.url
        if currentURL == targetURL {
            navigator.reload()
            self.targetURL = nil
            return
        }

        // If `next` is already on the navigation stack, pop to it (animated) and
        // resume routing from the completion block.
        let nextURL = Self.nextRouteURL(from: currentURL, to: targetURL)
        let rootVC = navigator.rootViewController
        if let targetVC = rootVC.viewControllers.last(where: { vc in
            guard let visitable = vc as? Visitable else { return false }
            return visitable.currentVisitableURL.path() == nextURL.path()
        }), targetVC !== rootVC.topViewController {
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                guard let self, let targetURL = self.targetURL else { return }
                if nextURL == targetURL {
                    self.targetURL = nil
                    navigator.reload()
                } else {
                    routeTowardsTargetURL()
                }
            }
            rootVC.popToViewController(targetVC, animated: true)
            CATransaction.commit()
            return
        }

        let nextPathProperties = Hotwire.config.pathConfiguration.properties(for: nextURL)
        trace(
            "routeTowardsTargetURL",
            [
                "targetURL": targetURL,
                "currentURL": currentURL as Any,
                "nextURL": nextURL,
                "nextPathProperties": nextPathProperties,
            ]
        )
        navigator.route(nextURL)
        if nextURL == targetURL {
            self.targetURL = nil
        }
    }

}

extension SceneController: UIWindowSceneDelegate {
    // Triggers from a cold start
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        window?.rootViewController = navigator.rootViewController
        launchOverlay.install(over: navigator.rootViewController.view)
        if let userActivity = connectionOptions.userActivities.first,
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL
        {
            targetURL = rewriteURLWithCanonicalBaseURL(incomingURL)
        } else if let response = connectionOptions.notificationResponse,
            let incomingURL = notificationTargetURL(response.notification)
        {
            targetURL = incomingURL
        }
        Task {
            await DeviceIdentifier.shared.setDefaultCookie()
            await MainActor.run {
                UNUserNotificationCenter.current().delegate = self
                navigator.start()
            }
        }
    }

    // Triggers when app is running in the background
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType != NSUserActivityTypeBrowsingWeb {
            return
        }
        if let incomingURL = userActivity.webpageURL {
            targetURL = rewriteURLWithCanonicalBaseURL(incomingURL)
            routeTowardsTargetURL()
        }
    }

    //  func sceneDidDisconnect(_ scene: UIScene) {}
    //  func sceneDidBecomeActive(_ scene: UIScene) {}
    //  func sceneWillResignActive(_ scene: UIScene) {}
    //  func sceneWillEnterForeground(_ scene: UIScene) {}
    //  func sceneDidEnterBackground(_ scene: UIScene) {}

}

extension SceneController: NavigatorDelegate {
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {

        // Never let `action: replace` swap out a `replace_root` page (like
        // /home) — that strands the user with no way back. This shows up most
        // visibly when a modal session redirects to a default-context URL:
        // Hotwire pops the modal then routes the redirected URL on the main
        // session with action=replace (its default for redirected proposals),
        // which then replaceLastViewController's /home. Re-route as .advance
        // so the page pushes on top of /home instead.
        // See docs/hotwire-native-ios.md.
        if proposal.options.action == .replace,
            let topVisitable = navigator.rootViewController.topViewController as? Visitable,
            Self.isRootPath(topVisitable.currentVisitableURL)
        {
            trace(
                "handle(overriding replace → advance to preserve root)",
                ["url": proposal.url.absoluteString]
            )
            DispatchQueue.main.async {
                navigator.route(proposal.url, options: VisitOptions(action: .advance))
            }
            return .reject
        }
        
        switch proposal.viewController {
        case QRCodeScannerController.pathConfigurationIdentifier:
            trace(
                "handle",
                [
                    "url": proposal.url.absoluteString,
                    "viewController": String(describing: proposal.viewController),
                ]
            )
            let controller = buildQRCodeScannerController()
            return .acceptCustom(controller)
        default:
            trace(
                "handle",
                [
                    "url": proposal.url.absoluteString,
                    "pathConfiguration": proposal.properties,
                ]
            )
            return .accept
        }
    }

    // Continues routing towards targetURL unless currently errored.
    func requestDidFinish(at url: URL) {
        if launchOverlay.isInstalled {
            launchOverlay.dismiss()
        }
        let isLastErroredURL = lastErroredURL == url
        trace(
            "requestDidFinish",
            [
                "url": url,
                "targetURL": String(describing: targetURL),
                "isLastErroredURL": isLastErroredURL,
            ]
        )
        if !isLastErroredURL, targetURL != nil {
            routeTowardsTargetURL(currentURL: url)
        }
    }

    func visitableDidFailRequest(
        _ visitable: Visitable,
        error: Error,
        retryHandler: RetryBlock?
    ) {
        trace("visitableDidFailRequest", ["error": error, "url": visitable.currentVisitableURL])
        // if let turboError = error as? TurboError, case .http(let statusCode) = turboError,
        //     statusCode == 401
        // {
        //     logger.debug("Got 401 status code; prompting for authentication...")
        //     promptForAuthentication()
        // } else if let errorPresenter = visitable as? ErrorPresenter {
        //     lastErroredURL = visitable.currentVisitableURL
        //     errorPresenter.presentError(error, retryHandler: retryHandler)
        // }
        lastErroredURL = visitable.currentVisitableURL
        if let errorPresenter = visitable as? ErrorPresenter {
            errorPresenter.presentError(error, retryHandler: retryHandler)
        }
    }

    // MARK: Helpers

    private func buildQRCodeScannerController() -> QRCodeScannerController {
        return QRCodeScannerController(delegate: self)
    }
}

extension SceneController: UNUserNotificationCenterDelegate {
    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even in foreground
        completionHandler([.banner, .sound])
    }

    // Handle notification interaction
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let targetURL = notificationTargetURL(response.notification) {
            self.targetURL = targetURL
            routeTowardsTargetURL()
        }
        completionHandler()
    }

    // MARK: Helpers

    private func notificationTargetURL(_ notification: UNNotification) -> URL? {
        let userInfo = notification.request.content.userInfo
        guard let targetString = userInfo["target_url"] as? String else {
            return nil
        }
        return URL(string: targetString, relativeTo: SmallerWorld.baseURL)
    }
}

extension SceneController: QRCodeScannerDelegate {
    func qrCodeScanner(
        _ controller: UIViewController,
        didScanQRCodeWithResult result: ScanResult,
    ) {
        let trimmedResult = result.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmedResult, relativeTo: SmallerWorld.baseURL)
        else {
            return
        }
        let canonicalURL = rewriteURLWithCanonicalBaseURL(url)
        targetURL = canonicalURL
        trace("qrCodeScanner(didScanQRCodeWithResult)", ["targetURL": canonicalURL])
        
        // Routing before the modal is gone makes `activeWebView` resolve to
        // `modalSession.webView`, which retains the URL of whatever the last
        // modal navigated to. See docs/hotwire-native-ios.md.
        controller.dismiss(animated: true) { [weak self] in
            self?.routeTowardsTargetURL()
        }
    }

    func qrCodeScanner(
        _ controller: UIViewController,
        didFailWithError error: ScanError
    ) {
        trace("qrCodeScanner(didFailWithError)", ["error": error.localizedDescription])
        controller.dismiss(animated: true)
    }

    // MARK: Helpers

    private func rewriteURLWithCanonicalBaseURL(_ url: URL) -> URL {
        if !SmallerWorld.isAppURL(url) {
            return url
        }
        guard
            var components = URLComponents(
                url: SmallerWorld.baseURL,
                resolvingAgainstBaseURL: true
            )
        else {
            return url
        }
        components.path = url.path
        components.query = url.query(percentEncoded: false)
        components.fragment = url.fragment
        return components.url ?? url
    }
}
