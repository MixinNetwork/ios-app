import UIKit

final class PerpetualMarketInfoCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpetualMarketInfoCellDidRequestInfo(_ cell: PerpetualMarketInfoCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titleInfoImageView: UIImageView!
    @IBOutlet weak var contentLabel: UILabel!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    @IBAction func requestInfo(_ sender: Any) {
        delegate?.perpetualMarketInfoCellDidRequestInfo(self)
    }
    
}
