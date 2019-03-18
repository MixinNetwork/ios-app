import UIKit
import SDWebImage

class ContactMeCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_contact_me"
    static let cellHeight: CGFloat = 90

    @IBOutlet weak var avatarImageView: AvatarShadowIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }

    func render(account: Account) {
        avatarImageView.setImage(with: account.avatar_url, identityNumber: account.identity_number, name: account.full_name)
        nameLabel.text = account.full_name
        mixinIDLabel.text = Localized.CONTACT_IDENTITY_NUMBER(identityNumber: account.identity_number)
    }
}
