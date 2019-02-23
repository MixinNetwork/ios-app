import UIKit
import SDWebImage

class PeerCell: UITableViewCell {
    
    static let cellIdentifier = "cell_identifier_contact"
    static let cellHeight: CGFloat = 70
    
    @IBOutlet weak var selectionImageView: UIImageView!
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var identityImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var selectionView: UIStackView!
    
    @IBOutlet weak var contentStackViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentStackViewTrailingConstraint: NSLayoutConstraint!
    
    var usesModernStyle: Bool = false {
        didSet {
            if usesModernStyle {
                contentStackViewLeadingConstraint.constant = 20
                contentStackViewTrailingConstraint.constant = 20
                let view = UIView()
                view.backgroundColor = .modernCellSelection
                selectedBackgroundView = view
            } else {
                contentStackViewLeadingConstraint.constant = 15
                contentStackViewTrailingConstraint.constant = 15
                selectedBackgroundView = nil
            }
        }
    }
    
    var supportsMultipleSelection = false {
        didSet {
            selectionView.isHidden = !supportsMultipleSelection
            selectionStyle = supportsMultipleSelection ? .none : .blue
        }
    }
    
    private var forceSelected = false

    override func awakeFromNib() {
        super.awakeFromNib()

        selectionImageView.layer.applySketchShadow(color: UIColor(rgbValue: 0x397EE4), alpha: 0.3, x: 0, y: 6, blur: 9, spread: 0)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        forceSelected = false
        iconImageView.sd_cancelCurrentImageLoad()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if forceSelected {
            selectionImageView.image = #imageLiteral(resourceName: "ic_member_disabled")
        } else {
            selectionImageView.image = selected ? #imageLiteral(resourceName: "ic_row_selected") : #imageLiteral(resourceName: "ic_row_normal")
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
