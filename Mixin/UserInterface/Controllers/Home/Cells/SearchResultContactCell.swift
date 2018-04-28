import UIKit
import SDWebImage

class SearchResultContactCell: UITableViewCell {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var verifiedImageView: UIImageView!
    
    override func prepareForReuse() {
        avatarImageView.sd_cancelCurrentImageLoad()
    }
    
    func render(user: UserItem) {
        avatarImageView.setImage(with: user.avatarUrl, identityNumber: user.identityNumber, name: user.fullName)
        nameLabel.text = user.fullName
        if user.isVerified {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            verifiedImageView.isHidden = false
        } else if user.isBot {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            verifiedImageView.isHidden = false
        } else {
            verifiedImageView.isHidden = true
        }
    }
    
}
