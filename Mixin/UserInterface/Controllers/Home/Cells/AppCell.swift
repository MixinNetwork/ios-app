import UIKit
import MixinServices

class AppCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: AvatarImageView!
    @IBOutlet weak var label: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.prepareForReuse()
    }
    
    func render(user: UserItem) {
        imageView.setImage(with: user)
        label.text = user.fullName
    }
    
}
