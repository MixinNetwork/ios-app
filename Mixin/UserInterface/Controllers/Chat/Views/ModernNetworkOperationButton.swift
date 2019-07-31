import UIKit

class ModernNetworkOperationButton: NetworkOperationButton {
    
    override var indicatorLineWidth: CGFloat {
        return 2
    }
    
    override var indicatorColor: UIColor {
        return .white
    }
    
    override class func makeBackgroundView() -> UIView {
        let view = UIVisualEffectView(effect: .darkBlur)
        view.clipsToBounds = true
        return view
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.layer.cornerRadius = backgroundSize.width / 2
    }
    
}
