import UIKit

final class MediaPreviewMaskView: UIView {
    
    private let topGradientLayer = CAGradientLayer()
    private let bottomGradientLayer = CAGradientLayer()
    
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
        topGradientLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 88)
        let bottomGradientHeight: CGFloat = 190
        bottomGradientLayer.frame = CGRect(x: 0, y: bounds.height - bottomGradientHeight, width: bounds.width, height: bottomGradientHeight)
    }
    
    private func prepare() {
        topGradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.3).cgColor,
            UIColor.black.withAlphaComponent(0.0).cgColor
        ]
        topGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        topGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        topGradientLayer.opacity = 0.6
        layer.addSublayer(topGradientLayer)
        bottomGradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor
        ]
        bottomGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        bottomGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        bottomGradientLayer.opacity = 0.6
        layer.addSublayer(bottomGradientLayer)
    }
    
}
