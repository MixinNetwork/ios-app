import UIKit

class UserHandleCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var identityNumberLabel: UILabel!
    
    func render(user: User) {
        avatarImageView.setImage(with: user)
        nameLabel.text = user.fullName
        if user.isVerified ?? false {
            badgeImageView.image = R.image.ic_user_verified()
        } else {
            badgeImageView.image = R.image.ic_user_bot()
        }
        identityNumberLabel.text = "@" + user.identityNumber
    }
    
}
