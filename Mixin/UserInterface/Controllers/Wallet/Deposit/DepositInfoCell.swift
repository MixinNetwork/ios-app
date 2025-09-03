import UIKit

final class DepositInfoCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func depositInfoCellDidRequestInfo(_ cell: DepositInfoCell)
        func depositInfoCellDidRequestCopyDescription(_ cell: DepositInfoCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var copyButton: UIButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
    @IBAction func requestInfo(_ sender: Any) {
        delegate?.depositInfoCellDidRequestInfo(self)
    }
    
    @IBAction func requestCopy(_ sender: Any) {
        delegate?.depositInfoCellDidRequestCopyDescription(self)
    }
    
}
