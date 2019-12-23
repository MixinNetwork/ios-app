import UIKit
import MixinServices

protocol FavoriteAppCellDelegate: class {
    func favoriteAppCellDidSelectAccessoryButton(_ cell: FavoriteAppCell)
}

class FavoriteAppCell: UITableViewCell {
    
    @IBOutlet weak var accessoryButton: UIButton!
    @IBOutlet weak var infoView: PeerInfoView!
    
    var isFavorite = false {
        didSet {
            let image = isFavorite ? R.image.ic_shared_app_remove() : R.image.ic_shared_app_add()
            accessoryButton.setImage(image, for: .normal)
        }
    }
    
    weak var delegate: FavoriteAppCellDelegate?
    
    func render(user: User) {
        infoView.render(user: user, userBiographyAsSubtitle: false)
    }
    
    @IBAction func accessoryAction(_ sender: Any) {
        delegate?.favoriteAppCellDidSelectAccessoryButton(self)
    }
    
}
