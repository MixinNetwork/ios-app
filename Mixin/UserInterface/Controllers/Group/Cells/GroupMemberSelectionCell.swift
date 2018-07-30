import UIKit
import SDWebImage

class GroupMemberSelectionCell: UITableViewCell {

    @IBOutlet weak var selectionImageView: UIImageView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var verifiedImageView: UIImageView!
    private var user: GroupUser?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.sd_cancelCurrentImageLoad()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = nameLabel.convert(.zero, to: self).x
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        guard !isDisabled else {
            return
        }
        selectionImageView.image = selected ? #imageLiteral(resourceName: "ic_member_selected") : #imageLiteral(resourceName: "ic_member_not_selected")
    }

    internal var isDisabled: Bool {
        return user?.disabled ?? true
    }

    func render(user: GroupUser) {
        self.user = user
        nameLabel.text = user.fullName
        avatarImageView.setImage(with: user.avatarUrl, identityNumber: user.identityNumber, name: user.fullName)
        if user.disabled {
            selectionImageView.image = #imageLiteral(resourceName: "ic_member_disabled")
        }
        displayVerifiedIcon(isVerified: user.isVerified, isBot: user.isBot)
    }

    internal func displayVerifiedIcon(isVerified: Bool, isBot: Bool) {
        if isVerified {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            verifiedImageView.isHidden = false
        } else if isBot {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            verifiedImageView.isHidden = false
        } else {
            verifiedImageView.isHidden = true
        }
    }
}
