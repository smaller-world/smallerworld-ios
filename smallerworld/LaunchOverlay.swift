import UIKit

final class LaunchOverlay {
    private weak var overlayView: UIView?
    private var observer: NSObjectProtocol?

    func install(over hostView: UIView) {
        guard
            let vc = UIStoryboard(name: "LaunchScreen", bundle: nil)
                .instantiateInitialViewController(),
            let overlay = vc.view
        else { return }

        overlay.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: hostView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
        ])

        self.overlayView = overlay

        observer = NotificationCenter.default.addObserver(
            forName: .pageLoadComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        guard let overlay = overlayView else { return }
        overlayView = nil
        UIView.animate(
            withDuration: 0.3,
            animations: { overlay.alpha = 0 },
            completion: { _ in overlay.removeFromSuperview() }
        )
    }

    var isInstalled: Bool {
        overlayView != nil
    }
}
