import UIKit

final class ModalTopDecorationView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }

  // A subtle "rim light" layer to define the top edge
  private let rimLayer = CAGradientLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false

    setupMainGlow()
    setupRimHighlight()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Position the rim at the very top.
    // Slightly taller (2px) to catch the "curve" and create a glass-edge bevel effect.
    rimLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 1.0)
  }

  private func setupMainGlow() {
    guard let gradientLayer = layer as? CAGradientLayer else { return }

    // Use a radial gradient to create a soft, non-linear glow that emanates from the top center
    gradientLayer.type = .radial
    gradientLayer.colors = [
      UIColor.white.withAlphaComponent(0.1).cgColor,  // Brighter start to simulate the glass curve
      UIColor.white.withAlphaComponent(0.0).cgColor,
    ]

    // Start at top center
    gradientLayer.startPoint = CGPoint(x: 0.5, y: -0.2)
    // Very short vertical spread (y: 0.3) to fade out immediately, blending into the body.
    // Wide horizontal spread (x: 1.5) to keep the glow across the top edge.
    gradientLayer.endPoint = CGPoint(x: 1.3, y: 0.4)
  }

  private func setupRimHighlight() {
    // A horizontal gradient on the 1px rim line.
    // This creates a specular highlight that is brighter in the center and fades at the edges,
    // mimicking light hitting a curved glossy surface.
    rimLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
    rimLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    rimLayer.colors = [
      UIColor.white.withAlphaComponent(0.02).cgColor,
      UIColor.white.withAlphaComponent(0.4).cgColor,  // Brightest "shimmer" in center
      UIColor.white.withAlphaComponent(0.02).cgColor,
    ]
    rimLayer.locations = [0.1, 0.5, 0.9]

    layer.addSublayer(rimLayer)
  }
}
