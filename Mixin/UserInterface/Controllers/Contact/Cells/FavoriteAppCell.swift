import UIKit
import MixinServices

protocol FavoriteAppCellDelegate: AnyObject {
    func favoriteAppCellDidSelectAccessoryButton(_ cell: FavoriteAppCell)
}

final class FavoriteAppCell: PeerCell {
    
    override class var nib: UINib {
        UINib(resource: R.nib.favoriteAppCell)
    }
    
    override class var reuseIdentifier: String {
        R.reuseIdentifier.favorite_app.identifier
    }
    
    @IBOutlet weak var accessoryButton: UIButton!
    
    var isFavorite = false {
        didSet {
            let image = isFavorite ? R.image.ic_shared_app_remove() : R.image.ic_shared_app_add()
            accessoryButton.setImage(image, for: .normal)
        }
    }
    
    weak var delegate: FavoriteAppCellDelegate?
    
    func render(user: User) {
        peerInfoView.render(user: user, description: .identityNumber)
    }
    
    @IBAction func accessoryAction(_ sender: Any) {
        delegate?.favoriteAppCellDidSelectAccessoryButton(self)
    }
    
}
