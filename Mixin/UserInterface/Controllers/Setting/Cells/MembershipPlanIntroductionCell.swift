import UIKit
import SDWebImage
import MixinServices

final class MembershipPlanIntroductionCell: UICollectionViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    @IBOutlet weak var checkmarkImageView: UIImageView!
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
        checkmarkImageView.layer.cornerRadius = 10
        checkmarkImageView.layer.masksToBounds = true
    }
    
    func load(plan: SafeMembership.Plan, isCurrent: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.minimumLineHeight = 18
        let descriptionAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.text_secondary()!,
            .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
            .paragraphStyle: paragraphStyle,
        ]
        switch plan {
        case .basic:
            iconImageView.image = R.image.membership_advance_large()
            nameLabel.text = R.string.localizable.membership_advance()
            descriptionLabel.attributedText = NSAttributedString(
                string: R.string.localizable.membership_advance_description(),
                attributes: descriptionAttributes
            )
        case .standard:
            iconImageView.image = R.image.membership_elite_large()
            nameLabel.text = R.string.localizable.membership_elite()
            descriptionLabel.attributedText = NSAttributedString(
                string: R.string.localizable.membership_elite_description(),
                attributes: descriptionAttributes
            )
        case .premium:
            iconImageView.image = UserBadgeIcon.largeProsperityImage
            nameLabel.text = R.string.localizable.membership_prosperity()
            descriptionLabel.attributedText = NSAttributedString(
                string: R.string.localizable.membership_prosperity_description(),
                attributes: descriptionAttributes
            )
        }
        checkmarkImageView.isHidden = !isCurrent
    }
    
}
