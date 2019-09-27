import UIKit

class UserHandleCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var identityNumberLabel: UILabel!
    @IBOutlet weak var keywordLabel: UILabel!
    
    func render(user: User, keyword: String?) {
        avatarImageView.setImage(with: user)
        nameLabel.text = user.fullName
        if user.isVerified ?? false {
            badgeImageView.image = R.image.ic_user_verified()
        } else {
            badgeImageView.image = R.image.ic_user_bot()
        }
        identityNumberLabel.text = "@" + user.identityNumber
        keywordLabel.text = keyword
    }
    
}
