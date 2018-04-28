import UIKit

class GroupParticipantCell: UICollectionViewCell {

    @IBOutlet weak var imageView: AvatarImageView!
    @IBOutlet weak var label: UILabel!

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
}
