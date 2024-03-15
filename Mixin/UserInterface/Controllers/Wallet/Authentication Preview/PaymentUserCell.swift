import UIKit

final class PaymentUserCell: UICollectionViewCell {
    
    enum Badge {
        case verified
        case bot
    }
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    
    var badge: Badge? {
        didSet {
            switch badge {
            case .verified:
                badgeImageView.image = R.image.ic_user_verified()
            case .bot:
                badgeImageView.image = R.image.ic_user_bot()
            case nil:
                badgeImageView.image = nil
            }
            badgeImageView.isHidden = badgeImageView.image == nil
        }
    }
    
}
