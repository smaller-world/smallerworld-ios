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
    private lazy var navigator = Navigator(
        configuration: .init(
            name: "main",
            startLocation: SmallerWorld.homeURL
        ),
        delegate: self,
    )

    private func log(_ name: String, _ arguments: [String: Any] = [:]) {
        logger.debug("[SceneController] \(name) \(arguments)")
    }

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
}

extension SceneController: UIWindowSceneDelegate {
    // Triggers from a cold start
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        window?.rootViewController = navigator.rootViewController
        if let userActivity = connectionOptions.userActivities.first,
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL
        {
            targetURL = rewriteURLWithCanonicalBaseURL(incomingURL)
        } else if let response = connectionOptions.notificationResponse,
            let targetURL = notificationTargetURL(response.notification)
        {
            self.targetURL = targetURL
        }
        Task {
            await InstallationID.shared.setDefaultCookie()
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
            let canonicalURL = rewriteURLWithCanonicalBaseURL(incomingURL)
            targetURL = canonicalURL
            if routeTowards(canonicalURL) {
                targetURL = nil
            }
        }
    }

    //  func sceneDidDisconnect(_ scene: UIScene) {}
    //  func sceneDidBecomeActive(_ scene: UIScene) {}
    //  func sceneWillResignActive(_ scene: UIScene) {}
    //  func sceneWillEnterForeground(_ scene: UIScene) {}
    //  func sceneDidEnterBackground(_ scene: UIScene) {}

    // MARK: Helpers

    /// Splits a URL's path into route segments, merging any segment whose
    /// `"/" + name` appears in `SmallerWorld.unroutablePaths` with the segment
    /// that follows it. `nil` and `SmallerWorld.homeURL` both return `[]`.
    ///
    /// Examples (with unroutablePaths = ["/worlds"]):
    /// - nil                        => []
    /// - /home                      => []
    /// - /worlds/asdf-12-23         => ["worlds/asdf-12-23"]
    /// - /worlds/asdf-12-23/keys    => ["worlds/asdf-12-23", "keys"]
    static func routeSegments(of url: URL?) -> [String] {
        guard let url else { return [] }
        if url.path == SmallerWorld.homeURL.path { return [] }
        let raw = url.pathComponents.filter { $0 != "/" }
        var result: [String] = []
        var i = 0
        while i < raw.count {
            let asPath = "/" + raw[i]
            if SmallerWorld.unroutablePaths.contains(asPath), i + 1 < raw.count {
                result.append(raw[i] + "/" + raw[i + 1])
                i += 2
            } else {
                result.append(raw[i])
                i += 1
            }
        }
        return result
    }

    /// Builds a URL with the given route segments joined into its path
    /// (relative to `SmallerWorld.baseURL`). Empty segments yield `homeURL`.
    static func url(forRouteSegments segments: [String]) -> URL {
        if segments.isEmpty { return SmallerWorld.homeURL }
        let path = "/" + segments.joined(separator: "/")
        return SmallerWorld.baseURL.appendingPathComponent(path)
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
    static func nextURL(from: URL?, to: URL) -> URL {
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
            return Self.url(forRouteSegments: Array(toSegs.prefix(prefixCount + 1)))
        }
        // Retreating to the deepest shared ancestor.
        return Self.url(forRouteSegments: Array(toSegs.prefix(prefixCount)))
    }

    // Does an incremental route towards url, returns true if routing is complete, returns
    // false if routing needs to be continued (via requestDidFinish, or via the CATransaction
    // completion block after an animated pop).
    private func routeTowards(_ url: URL) -> Bool {
        if !SmallerWorld.isAppURL(url) {
            let safariViewController = SFSafariViewController(url: url)
            safariViewController.dismissButtonStyle = .close
            navigator.rootViewController.present(safariViewController, animated: true)
            return true
        }
        if let currentURL = navigator.activeWebView.url, currentURL == url {
            return true
        }

        let next = Self.nextURL(from: navigator.activeWebView.url, to: url)

        // If `next` is already on the navigation stack, pop to it (animated) and
        // resume routing from the completion block.
        let nav = navigator.rootViewController
        if let targetVC = nav.viewControllers.last(where: { vc in
            guard let visitable = vc as? Visitable else { return false }
            return visitable.currentVisitableURL.path() == next.path()
        }), targetVC !== nav.topViewController {
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                guard let self, let target = self.targetURL else { return }
                if self.routeTowards(target) { self.targetURL = nil }
            }
            nav.popToViewController(targetVC, animated: true)
            CATransaction.commit()
            return false
        }

        navigator.route(next)
        return next == url
    }
}

extension SceneController: NavigatorDelegate {
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        log(
            "handle",
            [
                "url": proposal.url.absoluteString,
                "viewController": String(describing: proposal.viewController),
            ]
        )
        switch proposal.viewController {
        case QRCodeScannerController.pathConfigurationIdentifier:
            let controller = buildQRCodeScannerController()
            return .acceptCustom(controller)
        default:
            return .accept
        }
    }

    // Continues routing towards targetURL unless currently errored.
    func requestDidFinish(at url: URL) {
        let isLastErroredURL = lastErroredURL == url
        log(
            "requestDidFinish",
            [
                "url": url,
                "targetURL": String(describing: targetURL),
                "isLastErroredURL": isLastErroredURL,
            ]
        )
        if !isLastErroredURL, let targetURL {
            if routeTowards(targetURL) {
                self.targetURL = nil
            }
        }
    }

    func visitableDidFailRequest(
        _ visitable: Visitable,
        error: Error,
        retryHandler: RetryBlock?
    ) {
        log("visitableDidFailRequest", ["error": error])
        if let turboError = error as? TurboError, case .http(let statusCode) = turboError,
            statusCode == 401
        {
            logger.debug("Got 401 status code; prompting for authentication...")
            promptForAuthentication()
        } else if let errorPresenter = visitable as? ErrorPresenter {
            lastErroredURL = visitable.currentVisitableURL
            errorPresenter.presentError(error, retryHandler: retryHandler)
        }
    }
    
//    func formSubmissionDidFinish(at url: URL) {
//        log("formSubmissionDidFinish", ["url": url])
//        for vc in navigator.rootViewController.viewControllers {
//            if vc != self, let webViewController = vc as? WebViewController {
//                webViewController.markContentAsStale()
//            }
//        }
//    }
//
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
        // Guard against crash when notification is received before tabs are loaded
        // guard HotwireTab.all.indices.contains(tabBarController.selectedIndex) else {
        //     return
        // }
        if let targetURL = notificationTargetURL(response.notification) {
            self.targetURL = targetURL
            if routeTowards(targetURL) {
                self.targetURL = nil
            }
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
            let url = URL(
                string: trimmedResult,
                relativeTo: SmallerWorld.baseURL
            )
        else {
            return
        }
        let canonicalURL = rewriteURLWithCanonicalBaseURL(url)
        route(canonicalURL)
    }

    func qrCodeScanner(
        _ controller: UIViewController,
        didFailWithError error: ScanError
    ) {
        logger.error("QR scan failed: \(error.localizedDescription)")
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
