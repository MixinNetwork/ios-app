import UIKit

class BottomShadowView: OneSideShadowView {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let height: CGFloat = 10
        shadowProviderLayer.frame = CGRect(x: 0, y: -height, width: bounds.width, height: height)
    }
    
}
