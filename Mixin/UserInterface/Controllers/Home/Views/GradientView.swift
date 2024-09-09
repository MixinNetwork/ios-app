import UIKit

final class GradientView: UIView {
    
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    
    var lightColors: [UIColor]? {
        didSet {
            updateColors()
        }
    }
    
    var darkColors: [UIColor]? {
        didSet {
            updateColors()
        }
    }
    
    var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }
    
    private func updateColors() {
        switch traitCollection.userInterfaceStyle {
        case .dark:
            gradientLayer.colors = darkColors?.map(\.cgColor)
        case .unspecified, .light:
            fallthrough
        @unknown default:
            gradientLayer.colors = lightColors?.map(\.cgColor)
        }
    }
    
}
