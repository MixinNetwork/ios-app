import UIKit

class NavigationAvatarIconView: AvatarShadowIconView {
    
    override func layoutIconImageView() {
        iconImageView.bounds.size = CGSize(width: 30, height: 30)
        iconImageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
}
