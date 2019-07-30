import UIKit

class ModernNetworkOperationButton: NetworkOperationButton {
    
    override var indicatorLineWidth: CGFloat {
        return 2
    }
    
    override var indicatorColor: UIColor {
        return R.color.color.tint_black()!
    }
    
    override class func makeBackgroundView() -> UIView {
        let view = UIVisualEffectView(effect: .lightBlur)
        view.clipsToBounds = true
        view.backgroundColor = R.color.color.blur_background()!
        return view
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.layer.cornerRadius = backgroundSize.width / 2
    }
    
}
