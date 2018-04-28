import UIKit

class PhoneContactCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var indexTitleLabel: UILabel!

    static let cellIdentifier = "cell_identifier_phone_contact"
    static let cellHeight: CGFloat = 60

    func render(contact: PhoneContact) {
        nameLabel.text = contact.fullName
        indexTitleLabel.text = contact.fullName[0]
    }
}


