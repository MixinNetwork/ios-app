import UIKit
import SDWebImage
import MixinServices

final class UserCenterCell: UICollectionViewCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var membershipImageView: SDAnimatedImageView!
    @IBOutlet weak var identityNumberLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let cornerRadius: CGFloat = 13
        contentView.layer.cornerRadius = cornerRadius
        contentView.layer.masksToBounds = true
        selectedBackgroundView = {
            let view = SelectedCellBackgroundView()
            view.layer.cornerRadius = cornerRadius
            view.layer.masksToBounds = true
            return view
        }()
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Left blank intentionally. This cell is designed to be used for myself only
    }
    
    func load(account: Account) {
        avatarImageView.setImage(with: account)
        nameLabel.text = account.fullName
        membershipImageView.image = account.membership?.badgeImage
        membershipImageView.isHidden = membershipImageView.image == nil
        let identityNumber = R.string.localizable.contact_mixin_id(account.identityNumber)
        identityNumberLabel.text = identityNumber
        accessibilityLabel = "\(account.fullName), \(identityNumber)"
    }
    
}
