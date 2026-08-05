import UIKit

/// Hosts the app's main content and, above it, transient full-screen overlays
/// such as the launch screen.
///
/// Overlays are installed as child view controllers rather than bare subviews,
/// so they participate normally in appearance callbacks, trait and safe-area
/// propagation, and rotation. And because they live inside the root hierarchy
/// rather than in a separate window stacked above it, anything *presented*
/// modally — `SFSafariViewController`, the QR scanner — correctly appears above
/// them instead of being hidden behind them.
final class RootContainerController: UIViewController {
    private let contentViewController: UIViewController
    private var overlayViewController: UIViewController?

    init(content: UIViewController) {
        self.contentViewController = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        embed(contentViewController)
    }

    // The container is the window's root, so without these the content's own
    // status bar preferences (from the navigation controller) would be ignored.
    override var childForStatusBarStyle: UIViewController? {
        overlayViewController ?? contentViewController
    }

    override var childForStatusBarHidden: UIViewController? {
        overlayViewController ?? contentViewController
    }

    var hasOverlay: Bool {
        overlayViewController != nil
    }

    /// Places `viewController` above the content, replacing any existing overlay.
    func setOverlay(_ viewController: UIViewController) {
        if let existing = overlayViewController {
            unembed(existing)
        }
        embed(viewController)
        overlayViewController = viewController
        setNeedsStatusBarAppearanceUpdate()
    }

    /// Fades out the current overlay, if any, and removes it.
    func removeOverlay(duration: TimeInterval) {
        guard let overlay = overlayViewController else { return }
        overlayViewController = nil
        setNeedsStatusBarAppearanceUpdate()
        UIView.animate(
            withDuration: duration,
            animations: { overlay.view.alpha = 0 },
            completion: { [weak self] _ in self?.unembed(overlay) }
        )
    }

    // MARK: Containment

    private func embed(_ child: UIViewController) {
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    private func unembed(_ child: UIViewController) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
}
