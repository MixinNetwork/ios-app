import UIKit
import SDWebImage

class SearchResultContactCell: UITableViewCell {
    
    static let height: CGFloat = 70
    
    @IBOutlet weak var shadowProviderView: UIView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var verifiedImageView: UIImageView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.sd_cancelCurrentImageLoad()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let rect = CGRect(x: 0, y: 5, width: 50, height: 50)
        let path = CGPath(ellipseIn: rect, transform: nil)
        shadowProviderView.layer.shadowPath = path
        shadowProviderView.layer.shadowColor = UIColor(rgbValue: 0x888888).cgColor
        shadowProviderView.layer.shadowOpacity = 0.26
        shadowProviderView.layer.shadowRadius = 5
    }
    
    func render(user: UserItem) {
        avatarImageView.setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
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
