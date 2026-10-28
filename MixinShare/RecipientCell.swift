import UIKit
import SDWebImage
import MixinServices

final class RecipientCell: UITableViewCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeImageView: SDAnimatedImageView!
    
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
        switch ConversationCategory(rawValue: conversation.category) {
        case .CONTACT:
            avatarImageView.setImage(with: conversation.avatarUrl,
                                     userId: conversation.userId,
                                     name: conversation.name)
            badgeImageView.image = UserBadgeIcon.smallImage(
                membership: conversation.membership,
                isVerified: conversation.isVerified,
                isBot: conversation.isBot
            )
        case .GROUP:
            avatarImageView.setGroupImage(with: conversation.iconUrl)
            badgeImageView.image = R.image.group_indicator_small()
        case .none:
            badgeImageView.image = nil
        }
        badgeImageView.isHidden = badgeImageView.image == nil
    }
    
}
