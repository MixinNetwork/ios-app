import UIKit

class ConversationDockCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let selectedBackgroundView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        selectedBackgroundView.backgroundColor = .selection
        selectedBackgroundView.layer.cornerRadius = 12
        selectedBackgroundView.clipsToBounds = true
        self.selectedBackgroundView = selectedBackgroundView
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
}
