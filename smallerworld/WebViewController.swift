import HotwireNative
import UIKit
import WebKit
import os

class WebViewController: HotwireWebViewController {
    private let topDecoration = ModalTopDecorationView()

    open override func viewDidLoad() {
        super.viewDidLoad()

        styleBackground()
        addTopDecoration()
        addCloseButtonToModals()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateTopDecorationVisibility()
    }

    // MARK: Helpers

    private func styleBackground() {
        if let color = UIColor(named: "BackgroundColor") {
            view.backgroundColor = color
        }
    }

    private func addTopDecoration() {
        view.addSubview(topDecoration)
        topDecoration.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topDecoration.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topDecoration.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topDecoration.topAnchor.constraint(equalTo: view.topAnchor),
            topDecoration.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])
    }

    private func addCloseButtonToModals() {
        if presentingViewController != nil {
            let action = UIAction { [unowned self] _ in
                dismiss(animated: true)
            }
            navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: action)
        }
    }

    private func updateTopDecorationVisibility() {
        topDecoration.isHidden = presentingViewController == nil
    }
}
