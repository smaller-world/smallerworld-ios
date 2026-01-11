import HotwireNative
import UIKit
import WebKit

open class WebViewController: HotwireWebViewController {
  private let topGradient = GradientOverlayView()

  open override func viewDidLoad() {
    super.viewDidLoad()
    if let color = UIColor(named: "BackgroundColor") {
      view.backgroundColor = color
    }

    view.addSubview(topGradient)
    topGradient.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      topGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      topGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      topGradient.topAnchor.constraint(equalTo: view.topAnchor),
      topGradient.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
    ])
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    let isModal =
      presentingViewController != nil || navigationController?.presentingViewController != nil
    topGradient.isHidden = !isModal
  }

  //    open override func visitableDidRender() {
  //        if navigationItem.title == nil && isRootView {
  //            navigationController?.setNavigationBarHidden(true, animated: false)
  //        }
  //    }
  //
  //    var isRootView: Bool {
  //        navigationController?.viewControllers.first === self
  //    }
}
