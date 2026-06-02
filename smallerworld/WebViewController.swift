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
            addModalTopDecoration()
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !hasTitle, let controller = navigationController,
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
        if let controller = navigationController, controller.isNavigationBarHidden {
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
