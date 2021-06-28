import UIKit

class FolderAppItemCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: AvatarImageView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.prepareForReuse()
    }
    
}
