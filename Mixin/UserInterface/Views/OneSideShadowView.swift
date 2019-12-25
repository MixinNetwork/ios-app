import UIKit

class OneSideShadowView: UIView {
    
    let shadowProviderLayer = CALayer()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    private func prepare() {
        layer.addSublayer(shadowProviderLayer)
        shadowProviderLayer.backgroundColor = UIColor.theme.cgColor
        shadowProviderLayer.shadowColor = UIColor.shadow.cgColor
        shadowProviderLayer.shadowOpacity = 0.2
        shadowProviderLayer.shadowOffset = CGSize(width: 0, height: 2)
        shadowProviderLayer.shadowRadius = 5
    }
    
}
