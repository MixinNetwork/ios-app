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
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            avatarImageView.setImage(with: conversation.avatarUrl,
                                     userId: conversation.userId,
                                     name: conversation.name)
            badgeImageView.image = UserBadgeIcon.image(
                membership: conversation.membership,
                isVerified: conversation.isVerified,
                isBot: conversation.isBot
            )
            badgeImageView.isHidden = badgeImageView.image == nil
        } else {
            avatarImageView.setGroupImage(with: conversation.iconUrl)
            badgeImageView.isHidden = true
        }
    }
    
}
