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
        nameLabel.text = user.fullName
        let badgeImage = user.badgeImage
        identityImageView.image = badgeImage
        identityImageView.isHidden = badgeImage == nil
    }
    
}
