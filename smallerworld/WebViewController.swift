import HotwireNative
import UIKit
import WebKit
import os

class WebViewController: HotwireWebViewController {
    private let modalTopDecoration = ModalTopDecorationView()
    private var previousInteractiveContentPopGestureEnabled: Bool?
    //    private var isShowingStaleContent = false
    //
    //    public func markContentAsStale() {
    //        isShowingStaleContent = true
    //    }

    // MARK: ViewController

    open override func viewDidLoad() {
        super.viewDidLoad()

        styleBackground()
        if presentingViewController != nil {
            addModalCloseButton()
            if modalPresentationStyle == .automatic {
                addModalTopDecoration()
            }
        }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if presentingViewController != nil {
            installBackdropDim()
        }
        if presentingViewController == nil,
            !hasTitle,
            let controller = navigationController,
            controller.viewControllers.count == 1
        {
            controller.setNavigationBarHidden(true, animated: animated)
        }
        if #available(iOS 26.0, *),
            let recognizer = navigationController?.interactiveContentPopGestureRecognizer
        {
            previousInteractiveContentPopGestureEnabled = recognizer.isEnabled
            recognizer.isEnabled = interactiveContentPopGestureEnabled
        }
        //        if isShowingStaleContent {
        //            visitableDelegate?.visitableDidRequestReload(self)
        //            isShowingStaleContent = false
        //        }
    }

    open override func viewWillDisappear(_ animated: Bool) {
        if presentingViewController != nil {
            removeBackdropDim()
        }
        if presentingViewController == nil,
            let controller = navigationController,
            controller.isNavigationBarHidden
        {
            controller.setNavigationBarHidden(false, animated: animated)
        }
        if #available(iOS 26.0, *),
            let previous = previousInteractiveContentPopGestureEnabled
        {
            navigationController?
                .interactiveContentPopGestureRecognizer?
                .isEnabled = previous
            previousInteractiveContentPopGestureEnabled = nil
        }
    }

    // MARK: Visitable

    override open func visitableDidRender() {
        super.visitableDidRender()
        if let controller = navigationController {
            controller.setNavigationBarHidden(
                !hasTitle && controller.viewControllers.count == 1,
                animated: true
            )
        }
    }

    // MARK: Helpers

    private func styleBackground() {
        if let color = UIColor(named: "BackgroundColor") {
            view.backgroundColor = color
        }
    }

    private func addModalTopDecoration() {
        view.addSubview(modalTopDecoration)
        modalTopDecoration.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            modalTopDecoration.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modalTopDecoration.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            modalTopDecoration.topAnchor.constraint(equalTo: view.topAnchor),
            modalTopDecoration.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
        ])
    }

    // MARK: iPad backdrop dimming

    private let backdropDimView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.alpha = 0
        return view
    }()

    private var shouldDimPresentingContent: Bool {
        // The system draws its own sheet scrim on real iPads, but not when the
        // iPad app runs on macOS — fill that gap there only.
        traitCollection.userInterfaceIdiom == .pad && ProcessInfo.processInfo.isiOSAppOnMac
    }

    private func installBackdropDim() {
        guard shouldDimPresentingContent,
            let container = presentingViewController?.view,
            backdropDimView.superview == nil
        else { return }

        container.addSubview(backdropDimView)
        NSLayoutConstraint.activate([
            backdropDimView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backdropDimView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backdropDimView.topAnchor.constraint(equalTo: container.topAnchor),
            backdropDimView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.backdropDimView.alpha = 1
            })
        } else {
            backdropDimView.alpha = 1
        }
    }

    private func removeBackdropDim() {
        guard backdropDimView.superview != nil else { return }
        if let coordinator = transitionCoordinator {
            coordinator.animate(
                alongsideTransition: { _ in
                    self.backdropDimView.alpha = 0
                },
                completion: { _ in
                    self.backdropDimView.removeFromSuperview()
                }
            )
        } else {
            backdropDimView.alpha = 0
            backdropDimView.removeFromSuperview()
        }
    }

    private func addModalCloseButton() {
        let action = UIAction { [unowned self] _ in
            dismiss(animated: true)
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: action
        )
    }

    private var interactiveContentPopGestureEnabled: Bool {
        let properties = Hotwire.config.pathConfiguration.properties(
            for: currentVisitableURL
        )
        return properties["interactive_content_pop_gesture_enabled"] as? Bool ?? true
    }

    var hasTitle: Bool {
        if let title = navigationItem.title {
            return !title.isEmpty
        } else {
            return false
        }
    }
}
