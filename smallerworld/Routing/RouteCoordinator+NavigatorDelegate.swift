import HotwireNative
import UIKit
import os

extension RouteCoordinator: NavigatorDelegate {
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {

        // Never let `action: replace` swap out a `replace_root` page (like
        // /home) — that strands the user with no way back. This shows up most
        // visibly when a modal session redirects to a default-context URL:
        // Hotwire pops the modal then routes the redirected URL on the main
        // session with action=replace (its default for redirected proposals),
        // which then replaceLastViewController's /home. Re-route as .advance
        // so the page pushes on top of /home instead.
        //
        // Gate on `context == .default`: this guard inspects the *main* nav
        // stack (`rootViewController`), whose top is always /home (a
        // replace_root page). A modal→modal redirect stays in the modal stack
        // and never touches the main stack, so without this gate the guard
        // mis-fires — rejecting Hotwire's clean `.replace` and re-issuing
        // `.advance`, which pushes a duplicate onto the modal stack instead of
        // replacing in place. See docs/hotwire-native-ios.md.
        if proposal.options.action == .replace,
            proposal.context == .default,
            let topVisitable = navigator.rootViewController.topViewController as? Visitable,
            RouteResolver.isRootPath(topVisitable.currentVisitableURL)
        {
            DispatchQueue.main.async {
                navigator.route(proposal.url, options: VisitOptions(action: .advance))
            }
            return .reject
        }

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
        if launchOverlay.isInstalled {
            launchOverlay.dismiss()
        }
        let isLastErroredURL = lastErroredURL == url
        if !isLastErroredURL, let targetURL {
            Log.routing.debug(
                "Finished loading \(url.absoluteString, privacy: .public) (pending target: \(targetURL.absoluteString, privacy: .public))"
            )
            routeTowardsTargetURL(currentURL: url)
        } else {
            Log.routing.debug(
                "Finished loading \(url.absoluteString, privacy: .public)"
            )
        }
    }

    func visitableDidFailRequest(
        _ visitable: Visitable,
        error: HotwireNativeError,
        retryHandler: RetryBlock?
    ) {
        let currentURL = visitable.currentVisitableURL
        Log.routing.error(
            "Request failed for \(currentURL.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        lastErroredURL = currentURL
        if let errorPresenter = visitable as? ErrorPresenter {
            errorPresenter.presentError(error, retryHandler: retryHandler)
        }
    }

    // MARK: Helpers

    private func buildQRCodeScannerController() -> QRCodeScannerController {
        return QRCodeScannerController(delegate: self)
    }
}
