import UIKit
import SDWebImage
import MixinServices

class ContactCell: ModernSelectedBackgroundCell {
    
    static let height: CGFloat = 80
    
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var identityImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.prepareForReuse()
    }
    
    func render(user: UserItem) {
        iconImageView.setImage(with: user.avatarUrl,
                               userId: user.userId,
                               name: user.fullName)
        render(fullName: user.fullName,
               isVerified: user.isVerified,
               isBot: user.isBot)
    }
    
    private func render(fullName: String, isVerified: Bool, isBot: Bool) {
        nameLabel.text = fullName
        if isVerified {
            identityImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            identityImageView.isHidden = false
        } else if isBot {
            identityImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            identityImageView.isHidden = false
        } else {
            identityImageView.isHidden = true
        }
    }
    
}
