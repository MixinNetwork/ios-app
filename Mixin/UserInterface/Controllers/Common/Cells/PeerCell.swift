import UIKit
import SDWebImage

class PeerCell: UITableViewCell {
    
    static let cellIdentifier = "cell_identifier_contact"
    static let cellHeight: CGFloat = 60
    
    @IBOutlet weak var selectionImageView: UIImageView!
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var identityImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    var supportsMultipleSelection = false {
        didSet {
            selectionImageView.isHidden = !supportsMultipleSelection
            selectionStyle = supportsMultipleSelection ? .none : .blue
        }
    }
    
    private var forceSelected = false
    
    override func prepareForReuse() {
        super.prepareForReuse()
        forceSelected = false
        iconImageView.sd_cancelCurrentImageLoad()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = nameLabel.convert(.zero, to: self).x
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if forceSelected {
            selectionImageView.image = #imageLiteral(resourceName: "ic_member_disabled")
        } else {
            selectionImageView.image = selected ? #imageLiteral(resourceName: "ic_member_selected") : #imageLiteral(resourceName: "ic_member_not_selected")
        }
    }
    
    func render(user: UserItem) {
        iconImageView.setImage(with: user.avatarUrl,
                               identityNumber: user.identityNumber,
                               name: user.fullName)
        render(fullName: user.fullName,
               isVerified: user.isVerified,
               isBot: user.isBot)
    }
    
    func render(user: GroupUser, forceSelected: Bool) {
        iconImageView.setImage(with: user.avatarUrl,
                               identityNumber: user.identityNumber,
                               name: user.fullName)
        render(fullName: user.fullName,
               isVerified: user.isVerified,
               isBot: user.isBot)
        self.forceSelected = forceSelected
    }
    
    func render(peer: Peer) {
        peer.setIconImage(to: iconImageView)
        render(fullName: peer.name,
               isVerified: peer.isVerified,
               isBot: peer.isBot)

    }
    
    private func render(fullName: String, isVerified: Bool, isBot: Bool) {
        nameLabel.text = fullName
        if isVerified {
            identityImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            identityImageView.isHidden = false
        } else if isBot {
            identityImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            identityImageView.isHidden = false
        } else {
            identityImageView.isHidden = true
        }
    }
    
}
