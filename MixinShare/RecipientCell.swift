import UIKit
import MixinServices

class RecipientCell: UITableViewCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView(frame: self.bounds)
        selectedBackgroundView?.backgroundColor = R.color.background_selection()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
    }
    
    func render(conversation: RecipientSearchItem) {
        titleLabel.text = conversation.name
        if conversation.isVerified {
            badgeImageView.image = R.image.ic_user_verified()
            badgeImageView.isHidden = false
        } else if conversation.isBot {
            badgeImageView.image = R.image.ic_user_bot()
            badgeImageView.isHidden = false
        } else {
            badgeImageView.isHidden = true
        }
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            avatarImageView.setImage(with: conversation.avatarUrl,
                                     userId: conversation.userId,
                                     name: conversation.name)
        } else {
            avatarImageView.setGroupImage(with: conversation.iconUrl)
        }
    }
}
