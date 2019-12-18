import UIKit

class SeparatorShadowView: UIView {
    
    @IBInspectable var hasLowerShadow: Bool = true {
        didSet {
            lowerShadowProviderLayer.isHidden = !hasLowerShadow
        }
    }
    
    let upperShadowProviderLayer = CALayer()
    let lowerShadowProviderLayer = CALayer()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let height: CGFloat = 10
        upperShadowProviderLayer.frame = CGRect(x: 0, y: -height, width: bounds.width, height: height)
        lowerShadowProviderLayer.frame = CGRect(x: 0, y: bounds.height, width: bounds.width, height: height)
    }
    
    private func prepare() {
        for shadowProviderLayer in [upperShadowProviderLayer, lowerShadowProviderLayer] {
            layer.addSublayer(shadowProviderLayer)
            shadowProviderLayer.backgroundColor = UIColor.clear.cgColor
            shadowProviderLayer.shadowColor = UIColor.shadow.cgColor
            shadowProviderLayer.shadowOpacity = 0.2
            shadowProviderLayer.shadowOffset = CGSize(width: 0, height: 2)
            shadowProviderLayer.shadowRadius = 5
        }
    }
    
}
