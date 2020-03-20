import UIKit
import MixinServices

class RecipientCell: UITableViewCell {

    static let height: CGFloat = 70
    static let reuseIdentifier = "recipient"

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var avatarLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!

    func render(conversation: RecipientSearchItem) {
        setAvatarImage(conversation: conversation)
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
    }

    private func setAvatarImage(conversation: RecipientSearchItem) {
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            if let url = URL(string: conversation.avatarUrl) {
                titleLabel.text = nil
                avatarImageView.sd_setImage(with: url, placeholderImage: R.image.ic_place_holder(), options: .lowPriority)
            } else {
                avatarImageView.image = UIImage(named: "AvatarBackground/color\(conversation.userId.positiveHashCode() % 24 + 1)")
                if let firstLetter = conversation.name.first {
                    titleLabel.text = String([firstLetter]).uppercased()
                } else {
                    titleLabel.text = nil
                }
            }
        } else {
            titleLabel.text = nil
            if !conversation.iconUrl.isEmpty {
                let url = AppGroupContainer.groupIconsUrl.appendingPathComponent(conversation.iconUrl)
                avatarImageView.sd_setImage(with: url, placeholderImage: nil, context: localImageContext)
            } else {
                avatarImageView.image = R.image.ic_conversation_group()
            }
        }
    }
}
