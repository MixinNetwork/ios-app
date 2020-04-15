import UIKit
import MixinServices

class PinnedHomeAppCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: AvatarImageView!
    
}

extension PinnedHomeAppCell: HomeAppCell {
    
    var imageViewFrame: CGRect {
        imageView.frame
    }
    
    func render(user: User) {
        imageView.setImage(with: user)
    }
    
    func render(app: EmbeddedApp) {
        imageView.image = app.icon
    }
    
}
