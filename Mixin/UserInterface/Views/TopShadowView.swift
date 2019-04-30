import UIKit

class TopShadowView: OneSideShadowView {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let height: CGFloat = 10
        shadowProviderLayer.frame = CGRect(x: 0, y: bounds.height, width: bounds.width, height: height)
    }
    
}
