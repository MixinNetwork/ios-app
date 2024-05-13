import UIKit

protocol InscriptionActionCellDelegate: AnyObject {
    func inscriptionActionCellRequestToSend(_ cell: InscriptionActionCell)
    func inscriptionActionCellRequestToShare(_ cell: InscriptionActionCell)
}

final class InscriptionActionCell: UITableViewCell {
    
    @IBOutlet weak var sendButton: BusyButton!
    @IBOutlet weak var shareButton: UIButton!
    
    weak var delegate: InscriptionActionCellDelegate?
    
    @IBAction func send(_ sender: UIButton) {
        delegate?.inscriptionActionCellRequestToSend(self)
    }
    
    @IBAction func share(_ sender: UIButton) {
        delegate?.inscriptionActionCellRequestToShare(self)
    }
    
}
