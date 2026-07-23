import CodeScanner
import UIKit
import os

extension RouteCoordinator: QRCodeScannerDelegate {
    func qrCodeScanner(
        _ controller: UIViewController,
        didScanQRCodeWithResult result: ScanResult,
    ) {
        let trimmedResult = result.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmedResult, relativeTo: SmallerWorld.baseURL)
        else {
            return
        }
        let canonicalURL = SmallerWorld.canonicalURL(for: url)
        targetURL = canonicalURL

        // Routing before the modal is gone makes `activeWebView` resolve to
        // `modalSession.webView`, which retains the URL of whatever the last
        // modal navigated to. See docs/hotwire-native-ios.md.
        controller.dismiss(animated: true) { [weak self] in
            self?.routeTowardsTargetURL()
        }
    }

    func qrCodeScanner(
        _ controller: UIViewController,
        didFailWithError error: ScanError
    ) {
        Log.app.error(
            "QR scan failed: \(error.localizedDescription, privacy: .public)"
        )
        controller.dismiss(animated: true)
    }
}
