import UIKit
import SDWebImage

class ContactMeCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_contact_me"
    static let cellHeight: CGFloat = 94

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!
    @IBOutlet weak var mobileLabel: UILabel!

    func render(account: Account) {
        avatarImageView.setImage(with: account.avatar_url, identityNumber: account.identity_number, name: account.full_name)
        nameLabel.text = account.full_name
        mixinIDLabel.text = Localized.CONTACT_IDENTITY_NUMBER(identityNumber: account.identity_number)
        mobileLabel.text = Localized.CONTACT_MOBILE(mobile: account.phone)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = 0
    }
}
