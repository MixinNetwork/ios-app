import UIKit

final class PerpetualPositionCompactInfoCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpetualPositionCompactInfoCellDidSelectInfo(_ cell: PerpetualPositionCompactInfoCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var contentLabel: MarketColoredLabel!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        delegate = nil
    }
    
    @IBAction func invokeInfo(_ sender: Any) {
        delegate?.perpetualPositionCompactInfoCellDidSelectInfo(self)
    }
    
}
