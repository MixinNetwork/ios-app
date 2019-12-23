import Foundation
import MixinServices

class MultisigUserCell: ModernSelectedBackgroundCell {

    static let cellIdentifier = "cell_identifier_multisig_user"

    @IBOutlet weak var avatarView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var verifiedImageView: UIImageView!
    
    func render(user: UserResponse) {
        avatarView.setImage(user: user)
        nameLabel.text = user.fullName
        idLabel.text = user.identityNumber

        if user.isVerified {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            verifiedImageView.isHidden = false
        } else if user.app != nil {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            verifiedImageView.isHidden = false
        } else {
            verifiedImageView.isHidden = true
        }
    }

}
