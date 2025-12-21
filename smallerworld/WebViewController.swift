import UIKit
import WebKit
import HotwireNative

open class WebViewController: HotwireWebViewController {
    open override func viewDidLoad() {
        super.viewDidLoad()
        if let color = UIColor(named: "BackgroundColor") {
            view.backgroundColor = color
        }
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

