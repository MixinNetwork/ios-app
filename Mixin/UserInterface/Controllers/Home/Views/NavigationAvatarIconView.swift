import UIKit

class NavigationAvatarIconView: AvatarShadowIconView {
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 44, height: 44)
    }
    
    override func layoutIconImageView() {
        iconImageView.bounds.size = CGSize(width: 30, height: 30)
        iconImageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
}
