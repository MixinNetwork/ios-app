import UIKit
import MixinServices

class BlockUserCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    func render(user: UserItem) {
        avatarImageView.setImage(with: user)
        nameLabel.text = user.fullName
    }
    
}
