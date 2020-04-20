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

extension AppCell: HomeAppCell {
    
    var imageViewFrame: CGRect {
        imageView.frame
    }
    
    func render(user: User) {
        imageView.setImage(with: user)
        label.text = user.fullName
    }
    
    func render(app: EmbeddedApp) {
        imageView.image = app.icon
        label.text = app.name
    }
    
}
