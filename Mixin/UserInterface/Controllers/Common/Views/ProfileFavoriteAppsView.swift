import UIKit

class ProfileFavoriteAppsView: UIView, XibDesignable {
    
    @IBOutlet weak var avatarStackView: UserAvatarStackView!
    @IBOutlet weak var button: UIButton!
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 320, height: 64)
    }
    
}
