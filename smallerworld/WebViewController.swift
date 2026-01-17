import HotwireNative
import UIKit
import WebKit
import os

open class WebViewController: HotwireWebViewController {
  private let topDecoration = ModalTopDecorationView()

  open override func viewDidLoad() {
    super.viewDidLoad()

    configureAppearance()
    addTopDecoration()
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    updateTopDecorationVisibility()
  }

  // MARK: Helpers

  private func configureAppearance() {
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

  private func updateTopDecorationVisibility() {
    topDecoration.isHidden = presentingViewController == nil
  }
}
