import UIKit

class GroupMemberCell: UITableViewCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var roleLabel: UILabel!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var verifiedImageView: UIImageView!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = nameLabel.frame.origin.x
    }
    
    func render(user: GroupUser) {
        avatarImageView.setImage(with: user.avatarUrl, identityNumber: user.identityNumber, name: user.fullName)
        nameLabel.text = user.fullName
        roleLabel.text = ""
    }

    func render(user: UserItem) {
        avatarImageView.setImage(with: user.avatarUrl, identityNumber: user.identityNumber, name: user.fullName)
        nameLabel.text = user.fullName
        roleLabel.isHidden = false

        switch user.role {
        case ParticipantRole.ADMIN.rawValue, ParticipantRole.OWNER.rawValue:
            roleLabel.text = Localized.GROUP_ROLE_ADMIN
        default:
            roleLabel.text = ""
        }
        if !loadingView.isHidden {
            loadingView.stopAnimating()
            loadingView.isHidden = true
        }

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

    func startLoading() {
        roleLabel.text = ""
        loadingView.isHidden = false
        loadingView.startAnimating()
    }

    func stopLoading() {
        loadingView.stopAnimating()
        loadingView.isHidden = true
    }
}
