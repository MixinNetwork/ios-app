import UIKit

protocol ContactNavCellDelegate: class {

    func newGroupAction()

    func addContactAction()

}

class ContactNavCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_contact_nav"
    static let cellHeight: CGFloat = 72
    
    weak var delegate: ContactNavCellDelegate?

    @IBAction func newGroupAction(_ sender: Any) {
        delegate?.newGroupAction()
    }

    @IBAction func addContactAction(_ sender: Any) {
        delegate?.addContactAction()
    }
}

