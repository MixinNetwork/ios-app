import Foundation
import SDWebImage
import MixinServices

class MultisigUserCell: ModernSelectedBackgroundCell {

    static let cellIdentifier = "cell_identifier_multisig_user"

    @IBOutlet weak var avatarView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var verifiedImageView: SDAnimatedImageView!
    
    func render(user: UserItem) {
        avatarView.setImage(with: user)
        nameLabel.text = user.fullName
        idLabel.text = user.identityNumber
        verifiedImageView.image = user.badgeImage
        verifiedImageView.isHidden = verifiedImageView.image == nil
    }
    
}
