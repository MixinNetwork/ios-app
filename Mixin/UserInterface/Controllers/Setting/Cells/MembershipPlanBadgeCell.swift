import UIKit
import SDWebImage
import MixinServices

final class MembershipPlanBadgeCell: UICollectionViewCell {
    
    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.profile_badge()
        descriptionLabel.text = R.string.localizable.profile_badge_description()
    }
    
    func load(plan: SafeMembership.Plan) {
        iconImageView.image = switch plan {
        case .basic:
            R.image.membership_advance_large()
        case .standard:
            R.image.membership_elite_large()
        case .premium:
            UserBadgeIcon.largeProsperityImage
        }
    }
    
}
