import UIKit

class HomeAppItemCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: AvatarImageView!
    @IBOutlet weak var label: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.prepareForReuse()
    }
    
}
