import UIKit

class ContactNavCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_contact_nav"
    static let cellHeight: CGFloat = 64
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!

    func render(row: Int) {
        switch row {
        case 0:
            iconImageView.image = #imageLiteral(resourceName: "ic_contact_new_group")
            titleLabel.text = Localized.CONTACT_NEW_GROUP_TITLE
            summaryLabel.text = Localized.CONTACT_NEW_GROUP_SUMMARY
        case 1:
            iconImageView.image = #imageLiteral(resourceName: "ic_contact_search")
            titleLabel.text = Localized.CONTACT_ADD_TITLE
            summaryLabel.text = Localized.CONTACT_ADD_SUMMARY
        default:
            iconImageView.image = #imageLiteral(resourceName: "ic_contact_qrcode")
            titleLabel.text = Localized.CONTACT_QR_CODE_TITLE
            summaryLabel.text = Localized.CONTACT_QR_CODE_SUMMARY
        }
    }
}

