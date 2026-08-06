import CodeScanner
import UIKit
import os

extension RouteCoordinator: QRCodeScannerDelegate {
    func qrCodeScanner(
        _ controller: QRCodeScannerController,
        didScanQRCodeWithResult result: ScanResult,
    ) {
        // The scanner stays live after a rejected code, so ignore anything it
        // reports while it's on its way out from an accepted one.
        guard !controller.isBeingDismissed else {
            return
        }

        let trimmedResult = result.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmedResult, relativeTo: SmallerWorld.baseURL),
            SmallerWorld.isAppURL(url)
        else {
            controller.showScanError("sorry, this isn't a smaller world qr code!")
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        targetURL = SmallerWorld.canonicalURL(for: url)

        // Routing before the modal is gone makes `activeWebView` resolve to
        // `modalSession.webView`, which retains the URL of whatever the last
        // modal navigated to. See docs/hotwire-native-ios.md.
        controller.dismiss(animated: true) { [weak self] in
            self?.routeTowardsTargetURL()
        }
    }

    func qrCodeScanner(
        _ controller: QRCodeScannerController,
        didFailWithError error: ScanError
    ) {
        Log.app.error(
            "QR scan failed: \(error.localizedDescription, privacy: .public)"
        )
        controller.dismiss(animated: true)
    }
}
