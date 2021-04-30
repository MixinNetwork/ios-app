import UIKit

protocol PhoneContactCellDelegate: AnyObject {
    func phoneContactCellDidSelectInvite(_ cell: PhoneContactCell)
}

class PhoneContactCell: UITableViewCell {
    
    static let height: CGFloat = 80
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var indexTitleLabel: UILabel!
    @IBOutlet weak var phoneLabel: UILabel!
    
    weak var delegate: PhoneContactCellDelegate?
    
    func render(contact: PhoneContact) {
        nameLabel.text = contact.fullName
        indexTitleLabel.text = contact.fullName[0]
        phoneLabel.text = contact.phoneNumber
    }
    
    @IBAction func inviteAction(_ sender: Any) {
        delegate?.phoneContactCellDidSelectInvite(self)
    }
    
}
