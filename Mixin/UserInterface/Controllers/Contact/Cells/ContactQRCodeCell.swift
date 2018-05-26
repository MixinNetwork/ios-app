import UIKit

protocol ContactQRCodeCellDelegate: class {

    func receiveMoneyAction()

    func myQRCodeAction()

}

class ContactQRCodeCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_qr_code"
    static let cellHeight: CGFloat = 60

    weak var delegate: ContactQRCodeCellDelegate?

    @IBOutlet weak var separatorView: UIView!
    
    func render(separatorColor: UIColor?) {
        guard let color = separatorColor else {
            return
        }
        separatorView.backgroundColor = color
    }

    @IBAction func receiveMoneyAction(_ sender: Any) {
        delegate?.receiveMoneyAction()
    }

    @IBAction func myQRCodeAction(_ sender: Any) {
        delegate?.myQRCodeAction()
    }

}
