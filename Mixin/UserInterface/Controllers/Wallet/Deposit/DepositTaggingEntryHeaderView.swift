import UIKit

final class DepositTaggingEntryHeaderView: UICollectionReusableView {
    
    @IBOutlet weak var contentView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
    
}
