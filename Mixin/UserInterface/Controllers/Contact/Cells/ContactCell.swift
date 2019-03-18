import UIKit
import SDWebImage

class ContactCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_contact"
    static let cellHeight: CGFloat = 70

    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var identityImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
    }

    func render(user: UserItem) {
        iconImageView.setImage(with: user.avatarUrl,
                               identityNumber: user.identityNumber,
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
