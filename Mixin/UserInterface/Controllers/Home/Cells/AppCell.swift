import UIKit

final class AppCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: AvatarImageView!
    @IBOutlet weak var label: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.prepareForReuse()
        label?.isHidden = false
    }
    
}
