import UIKit
import SDWebImage
import MixinServices

final class MembershipPlanIntroductionCell: UICollectionViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contentStackView.setCustomSpacing(12, after: iconImageView)
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    func load(plan: SafeMembership.Plan) {
        switch plan {
        case .basic:
            iconImageView.image = R.image.membership_advance_large()
            nameLabel.text = R.string.localizable.membership_advance()
            descriptionLabel.text = R.string.localizable.membership_advance_description()
        case .standard:
            iconImageView.image = R.image.membership_elite_large()
            nameLabel.text = R.string.localizable.membership_elite()
            descriptionLabel.text = R.string.localizable.membership_elite_description()
        case .premium:
            iconImageView.image = UserBadgeIcon.prosperityImage(dimension: 70)
            nameLabel.text = R.string.localizable.membership_prosperity()
            descriptionLabel.text = R.string.localizable.membership_prosperity_description()
        }
    }
    
}
