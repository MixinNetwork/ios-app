import UIKit

protocol ContactQRCodeCellDelegate: class {

    func receiveMoneyAction()

    func myQRCodeAction()

}

class ContactQRCodeCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_qr_code"
    static let cellHeight: CGFloat = 66

    weak var delegate: ContactQRCodeCellDelegate?

    @IBAction func receiveMoneyAction(_ sender: Any) {
        delegate?.receiveMoneyAction()
    }

    @IBAction func myQRCodeAction(_ sender: Any) {
        delegate?.myQRCodeAction()
    }

}
