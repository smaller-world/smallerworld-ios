import UIKit
import os

/// Keeps the launch screen on screen past the system's own dismissal, so the
/// user never sees the web app's loading indicator during a cold start.
///
/// The launch screen is installed as an overlay on `RootContainerController`,
/// which owns the containment mechanics; this type owns only the policy of
/// when the overlay comes down. That is the first of:
///   - `.pageLoadComplete` — the `page-load` bridge component connected, i.e.
///     the page is actually rendered and interactive. This is the happy path.
///   - `dismiss(reason:)` called explicitly — currently from
///     `visitableDidFailRequest`, so a failed load reveals the error screen
///     instead of hiding it behind the splash.
///   - `timeout` — a safety net. If the web app never reports back (an old
///     build without the bridge component, a JS error before it connects), we
///     must not strand the user on a splash screen forever.
final class LaunchOverlay {
    /// How long to hold the overlay before assuming the page will never report
    /// in. Generous on purpose: a slow cold start on a bad network is normal,
    /// and expiring early reintroduces the flash we're trying to suppress.
    private static let timeout: TimeInterval = 10

    private static let fadeDuration: TimeInterval = 0.3

    /// Weak: the container is retained by the window as its root.
    private weak var container: RootContainerController?
    private var observer: NSObjectProtocol?
    private var timeoutWorkItem: DispatchWorkItem?

    func install(in container: RootContainerController) {
        guard
            let viewController = UIStoryboard(name: "LaunchScreen", bundle: nil)
                .instantiateInitialViewController()
        else {
            Log.launch.error("Failed to instantiate LaunchScreen storyboard; overlay not installed")
            return
        }

        container.setOverlay(viewController)
        self.container = container

        observer = NotificationCenter.default.addObserver(
            forName: .pageLoadComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss(reason: "page load complete")
        }

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.dismiss(reason: "timed out waiting for page load")
        }
        self.timeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.timeout,
            execute: timeoutWorkItem
        )
    }

    func dismiss(reason: String) {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        guard let container, container.hasOverlay else { return }
        self.container = nil
        Log.launch.debug("Dismissing launch overlay: \(reason, privacy: .public)")
        container.removeOverlay(duration: Self.fadeDuration)
    }
}
