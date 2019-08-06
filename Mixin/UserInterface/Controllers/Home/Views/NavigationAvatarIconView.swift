import UIKit

class NavigationAvatarIconView: AvatarImageView {
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 44, height: 44)
    }
    
    override func layout(imageView: UIImageView) {
        imageView.bounds.size = CGSize(width: 30, height: 30)
        imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
}
