import UIKit

class ConversationExtensionCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var avatarImageView: BorderedAvatarImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        avatarImageView.prepareForReuse()
    }
    
}
