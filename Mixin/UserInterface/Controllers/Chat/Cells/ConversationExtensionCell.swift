import UIKit

class ConversationExtensionCell: UICollectionViewCell {
    
    @IBOutlet weak var selectionBackgroundView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    
    override var isSelected: Bool {
        didSet {
            selectionBackgroundView.alpha = isSelected ? 1 : 0
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = nil
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
}
