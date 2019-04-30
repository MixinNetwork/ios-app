import UIKit
import SDWebImage

class PeerCell: UITableViewCell {
    
    @IBOutlet weak var checkmarkView: CheckmarkView!
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var identityImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var selectionView: UIStackView!
    
    var supportsMultipleSelection = false {
        didSet {
            selectionView.isHidden = !supportsMultipleSelection
            selectionStyle = supportsMultipleSelection ? .none : .blue
        }
    }
    
    private var forceSelected = false

    override func awakeFromNib() {
        super.awakeFromNib()

        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        forceSelected = false
        iconImageView.sd_cancelCurrentImageLoad()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if forceSelected {
            checkmarkView.status = .forceSelected
        } else {
            checkmarkView.status = selected ? .selected : .unselected
        }
    }
    
    func render(user: UserItem) {
        iconImageView.setImage(with: user.avatarUrl,
                               userId: user.userId,
                               name: user.fullName)
        render(fullName: user.fullName,
               isVerified: user.isVerified,
               isBot: user.isBot)
    }
    
    func render(user: GroupUser, forceSelected: Bool) {
        iconImageView.setImage(with: user.avatarUrl,
                               userId: user.userId,
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
