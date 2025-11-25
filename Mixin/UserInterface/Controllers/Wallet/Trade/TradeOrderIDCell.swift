import UIKit

final class TradeOrderIDCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func swapOrderIDCellRequestCopy(_ cell: TradeOrderIDCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.text = R.string.localizable.order_id().uppercased()
    }
    
    @IBAction func requestCopy(_ sender: Any) {
        delegate?.swapOrderIDCellRequestCopy(self)
    }
    
}
