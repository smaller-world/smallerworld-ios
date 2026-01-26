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

        styleNavigationBar()
        addCloseButtonToModals()
        addHostingController()
    }

    // MARK: Helpers

    private func styleNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }
        let appearance = AppUI.navigationBarAppearance()
        appearance.titleTextAttributes[.foregroundColor] = UIColor.white
        navigationBar.standardAppearance = appearance
    }

    private func addCloseButtonToModals() {
        if presentingViewController != nil {
            let action = UIAction { [unowned self] _ in
                dismiss(animated: true)
            }
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                systemItem: .close, primaryAction: action)
        }
    }

    private func addHostingController() {
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

private struct ScannerView: View {
    let completion: (Result<ScanResult, ScanError>) -> Void
    @State private var isTorchOn = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scanFrameSize = size.width / 1.8
            let frameSize = size.width / 1.55
            let frameOriginY = (size.height - frameSize) / 2
            let cutoutRect = CGRect(
                x: (size.width - scanFrameSize) / 2,
                y: frameOriginY + ((frameSize - scanFrameSize) / 2),
                width: scanFrameSize,
                height: scanFrameSize
            )
            ZStack {
                CodeScannerView(codeTypes: [.qr], isTorchOn: isTorchOn, completion: completion)
                    .ignoresSafeArea()

                ScannerOverlay(
                    cutoutRect: cutoutRect,
                    frameSize: frameSize,
                    cornerRadius: 20,
                    cornerLength: 22,
                    frameLineWidth: 6,
                    isTorchOn: $isTorchOn
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
    @Binding var isTorchOn: Bool

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
                    .allowsHitTesting(false)

                CornerFrame(
                    cornerRadius: cornerRadius,
                    cornerLength: cornerLength,
                    lineWidth: frameLineWidth
                )
                .stroke(Color.white, style: StrokeStyle(lineWidth: frameLineWidth, lineCap: .round))
                .frame(width: frameSize, height: frameSize)
                .position(x: frameOrigin.x + frameSize / 2, y: frameOrigin.y + frameSize / 2)
                .allowsHitTesting(false)

                Text("align QR code within frame")
                    .font(.custom(AppFont.body, size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(Color.white.opacity(0.85))
                    .position(x: size.width / 2, y: frameOrigin.y - 24)
                    .allowsHitTesting(false)

                FlashlightButton(isTorchOn: $isTorchOn)
                    .position(x: size.width / 2, y: frameOrigin.y + frameSize + 44)
                    .allowsHitTesting(true)
            }
        }
    }
}

private struct FlashlightButton: View {
    @Binding var isTorchOn: Bool

    @ViewBuilder
    var base: some View {
        let label = isTorchOn ? "Turn off flashlight" : "Turn on flashlight"
        let icon = isTorchOn ? "flashlight.off.fill" : "flashlight.on.fill"
        let button = Button(action: { isTorchOn.toggle() }, label: {
            let label = Label(label, systemImage: icon)
                .font(.title)
                .padding(4)
                .labelStyle(.iconOnly)
            if isTorchOn {
                label.colorInvert()
            } else {
                label
            }
        })
            .buttonBorderShape(.circle)
        if isTorchOn {
            button.tint(.white)
        } else {
            button
        }
    }

    @ViewBuilder
    var body: some View {
        if !isTorchOn, #available(iOS 26.0, *) {
            base.buttonStyle(.glass)
        } else {
            base.buttonStyle(.borderedProminent)
        }
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
            .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
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
