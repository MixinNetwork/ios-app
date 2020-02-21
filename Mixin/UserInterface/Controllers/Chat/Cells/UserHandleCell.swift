import UIKit
import MixinServices

class UserHandleCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var identityNumberLabel: UILabel!
    
    private var normalNameAttributes = [NSAttributedString.Key: Any]()
    private var normalIdAttributes = [NSAttributedString.Key: Any]()
    
    private var keywordAttributes = [NSAttributedString.Key.foregroundColor: UIColor.theme]
    
    override func awakeFromNib() {
        super.awakeFromNib()
        normalNameAttributes[.font] = nameLabel.font
        normalNameAttributes[.foregroundColor] = nameLabel.textColor
        normalIdAttributes[.font] = identityNumberLabel.font
        normalIdAttributes[.foregroundColor] = identityNumberLabel.textColor
    }
    
    func render(user: UserItem, fullnameKeywordRange: NSRange?, identityNumberKeywordRange: NSRange?) {
        avatarImageView.setImage(with: user)
        nameLabel.attributedText = {
            let fullname = NSMutableAttributedString(string: user.fullName, attributes: normalNameAttributes)
            if let range = fullnameKeywordRange {
                fullname.addAttributes(keywordAttributes, range: range)
            }
            return fullname.copy() as? NSAttributedString
        }()
        if user.isVerified {
            badgeImageView.image = R.image.ic_user_verified()
        } else if user.isBot {
            badgeImageView.image = R.image.ic_user_bot()
        } else {
            badgeImageView.image = nil
        }
        identityNumberLabel.attributedText = {
            let number = NSMutableAttributedString(string: user.identityNumber, attributes: normalIdAttributes)
            if let range = identityNumberKeywordRange {
                number.addAttributes(keywordAttributes, range: range)
            }
            return number.copy() as? NSAttributedString
        }()
    }
    
}
