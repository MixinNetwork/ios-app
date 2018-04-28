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
        avatarImageView.setImage(with: user.avatarUrl, identityNumber: user.identityNumber, name: user.fullName)
        nameLabel.text = user.fullName
        if user.isVerified {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            verifiedImageView.isHidden = false
        } else if user.isBot {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            verifiedImageView.isHidden = false
        } else {
            verifiedImageView.isHidden = true
        }
    }
    
    func render(user: GroupUser) {
        avatarImageView.setImage(with: user.avatarUrl, identityNumber: user.identityNumber, name: user.fullName)
        nameLabel.text = user.fullName
    }
    
}

