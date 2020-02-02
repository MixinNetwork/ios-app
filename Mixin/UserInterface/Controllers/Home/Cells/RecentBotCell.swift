import UIKit
import MixinServices

class RecentAppCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
    func render(user: UserItem) {
        imageView.sd_setImage(with: URL(string: user.avatarUrl), completed: nil)
        label.text = user.fullName
    }
    
}
