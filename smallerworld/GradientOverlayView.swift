import UIKit

final class GradientOverlayView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    
    if let gradientLayer = layer as? CAGradientLayer {
      gradientLayer.colors = [
        UIColor.white.withAlphaComponent(0.1).cgColor,
        UIColor.white.withAlphaComponent(0.0).cgColor,
      ]
      gradientLayer.locations = [0.0, 1.0]
      gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
      gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
