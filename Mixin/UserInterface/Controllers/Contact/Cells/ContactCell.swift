import UIKit
import SDWebImage

class ContactCell: UITableViewCell {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var verifiedImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!

    static let cellIdentifier = "cell_identifier_contact"
    static let cellHeight: CGFloat = 60
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.sd_cancelCurrentImageLoad()
    }
    
    func render(user: UserItem) {
        render(avatarUrl: user.avatarUrl, identityNumber: user.identityNumber, fullName: user.fullName, isVerified: user.isVerified, isBot: user.isBot)
    }
    
    func render(user: GroupUser) {
        render(avatarUrl: user.avatarUrl, identityNumber: user.identityNumber, fullName: user.fullName, isVerified: user.isVerified, isBot: user.isBot)
    }

    func render(user: ForwardUser) {
        if user.isGroup {
            avatarImageView.setGroupImage(with: user.iconUrl, conversationId: user.conversationId)
            render(avatarUrl: "", identityNumber: "", fullName: user.name, isVerified: false, isBot: false, isGroup: true)
        } else {
            render(avatarUrl: user.ownerAvatarUrl, identityNumber: user.identityNumber, fullName: user.fullName, isVerified: user.ownerIsVerified, isBot: user.isBot)
        }
    }

    private func render(avatarUrl: String, identityNumber: String, fullName: String, isVerified: Bool, isBot: Bool, isGroup: Bool = false) {
        if !isGroup {
            avatarImageView.setImage(with: avatarUrl, identityNumber: identityNumber, name: fullName)
        }
        nameLabel.text = fullName
        if isVerified {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            verifiedImageView.isHidden = false
        } else if isBot {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            verifiedImageView.isHidden = false
        } else {
            verifiedImageView.isHidden = true
        }
    }
    
}

