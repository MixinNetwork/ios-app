import UIKit

protocol PhoneContactCellDelegate: AnyObject {
    func phoneContactCellDidSelectInvite(_ cell: PhoneContactCell)
}

class PhoneContactCell: PeerCell {
    
    weak var delegate: PhoneContactCellDelegate?

    override class var nib: UINib {
        UINib(nibName: "PhoneContactCell", bundle: .main)
    }
    
    override class var reuseIdentifier: String {
        "phone_contact"
    }
    
    @IBAction func inviteAction(_ sender: Any) {
        delegate?.phoneContactCellDidSelectInvite(self)
    }
    
}
