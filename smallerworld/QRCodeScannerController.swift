internal import AVFoundation
import CodeScanner
import HotwireNative
import SwiftUI
import UIKit

protocol QRCodeScannerDelegate: AnyObject {
    func qrCodeScanner(
        _ controller: UIViewController,
        didScanQRCodeWithResult result: ScanResult
    )

    func qrCodeScanner(
        _ controller: UIViewController,
        didFailWithError error: ScanError
    )
}

class QRCodeScannerController: UIViewController, PathConfigurationIdentifiable {
    public static var pathConfigurationIdentifier: String { "qr_code_scanner" }

    weak var delegate: QRCodeScannerDelegate?
    private lazy var scannerView = ScannerView { [weak self] response in
        guard let self else {
            return
        }
        switch response {
        case .success(let result):
            delegate?.qrCodeScanner(self, didScanQRCodeWithResult: result)
        case .failure(let error):
            delegate?.qrCodeScanner(self, didFailWithError: error)
        }
    }
    private lazy var hostingController = UIHostingController(rootView: scannerView)

    init(delegate: QRCodeScannerDelegate?) {
        super.init(nibName: nil, bundle: nil)

        self.delegate = delegate
        self.title = "scan QR code"
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

private struct ScannerView: View {
    let completion: (Result<ScanResult, ScanError>) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scanFrameSize = size.width / 1.8
            let frameSize = size.width / 1.5
            let frameOriginY = (size.height - frameSize) / 2
            let cutoutRect = CGRect(
                x: (size.width - scanFrameSize) / 2,
                y: frameOriginY + ((frameSize - scanFrameSize) / 2),
                width: scanFrameSize,
                height: scanFrameSize
            )
            ZStack {
                CodeScannerView(codeTypes: [.qr], completion: completion)
                    .ignoresSafeArea()

                ScannerOverlay(
                    cutoutRect: cutoutRect,
                    frameSize: frameSize,
                    cornerRadius: 20,
                    cornerLength: 22,
                    frameLineWidth: 6
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct ScannerOverlay: View {
    let cutoutRect: CGRect
    let frameSize: CGFloat
    let cornerRadius: CGFloat
    let cornerLength: CGFloat
    let frameLineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let frameOrigin = CGPoint(
                x: (size.width - frameSize) / 2,
                y: (size.height - frameSize) / 2
            )
            ZStack {
                CutoutOverlay(cutoutRect: cutoutRect, cornerRadius: cornerRadius)
                    .ignoresSafeArea()

                CornerFrame(
                    cornerRadius: cornerRadius,
                    cornerLength: cornerLength,
                    lineWidth: frameLineWidth
                )
                .stroke(Color.white, style: StrokeStyle(lineWidth: frameLineWidth, lineCap: .round))
                .frame(width: frameSize, height: frameSize)
                .position(x: frameOrigin.x + frameSize / 2, y: frameOrigin.y + frameSize / 2)

                Text("align QR code within frame")
                    .font(.custom(AppFont.body, size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(Color.white.opacity(0.85))
                    .position(x: size.width / 2, y: frameOrigin.y - 24)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CutoutOverlay: View {
    let cutoutRect: CGRect
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: proxy.size))
                path.addRoundedRect(
                    in: cutoutRect,
                    cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                )
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
        }
    }
}

private struct CornerFrame: Shape {
    let cornerRadius: CGFloat
    let cornerLength: CGFloat
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let adjustment = lineWidth / 2
        let minX = rect.minX + adjustment
        let minY = rect.minY + adjustment
        let maxX = rect.maxX - adjustment
        let maxY = rect.maxY - adjustment

        let path = UIBezierPath()

        // Top left
        path.move(to: CGPoint(x: minX, y: minY + cornerLength + cornerRadius))
        path.addLine(to: CGPoint(x: minX, y: minY + cornerRadius))
        path.addArc(
            withCenter: CGPoint(x: minX + cornerRadius, y: minY + cornerRadius),
            radius: cornerRadius,
            startAngle: CGFloat.pi,
            endAngle: CGFloat.pi * 3 / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: minX + cornerLength + cornerRadius, y: minY))

        // Top right
        path.move(to: CGPoint(x: maxX, y: minY + cornerLength + cornerRadius))
        path.addLine(to: CGPoint(x: maxX, y: minY + cornerRadius))
        path.addArc(
            withCenter: CGPoint(x: maxX - cornerRadius, y: minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 0,
            endAngle: CGFloat.pi * 3 / 2,
            clockwise: false
        )
        path.addLine(to: CGPoint(x: maxX - cornerLength - cornerRadius, y: minY))

        // Bottom left
        path.move(to: CGPoint(x: minX, y: maxY - cornerLength - cornerRadius))
        path.addLine(to: CGPoint(x: minX, y: maxY - cornerRadius))
        path.addArc(
            withCenter: CGPoint(x: minX + cornerRadius, y: maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: CGFloat.pi,
            endAngle: CGFloat.pi / 2,
            clockwise: false
        )
        path.addLine(to: CGPoint(x: minX + cornerLength + cornerRadius, y: maxY))

        // Bottom right
        path.move(to: CGPoint(x: maxX, y: maxY - cornerLength - cornerRadius))
        path.addLine(to: CGPoint(x: maxX, y: maxY - cornerRadius))
        path.addArc(
            withCenter: CGPoint(x: maxX - cornerRadius, y: maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: 0,
            endAngle: CGFloat.pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: maxX - cornerLength - cornerRadius, y: maxY))

        return Path(path.cgPath)
    }
}
