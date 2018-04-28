import UIKit

protocol PhoneContactGuideCellDelegate: class {

    func requestAccessPhoneContactAction()

}

class PhoneContactGuideCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_phone_contact_guide"
    static let cellHeight: CGFloat = 44

    weak var delegate: PhoneContactGuideCellDelegate?

    @IBAction func requestAccessPhoneContactAction(_ sender: Any) {
        delegate?.requestAccessPhoneContactAction()
    }
}



