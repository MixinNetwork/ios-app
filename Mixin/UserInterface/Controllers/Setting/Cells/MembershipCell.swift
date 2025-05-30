import UIKit
import MixinServices

final class MembershipCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func membershipCellDidSelectViewPlan(_ cell: MembershipCell)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var membershipStackView: UIStackView!
    @IBOutlet weak var membershipLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var expirationLabel: UILabel!
    @IBOutlet weak var viewPlanButton: UIButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(14, after: membershipStackView)
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        expirationLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        viewPlanButton.titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel.text = R.string.localizable.membership_plan()
    }
    
    func load(plan: User.Membership.Plan, expiredAt: Date) {
        switch plan {
        case .advance:
            membershipLabel.text = R.string.localizable.membership_advance()
            badgeImageView.image = R.image.membership_advance_large()
        case .elite:
            membershipLabel.text = R.string.localizable.membership_elite()
            badgeImageView.image = R.image.membership_elite_large()
        case .prosperity:
            membershipLabel.text = R.string.localizable.membership_prosperity()
            badgeImageView.image = UserBadgeIcon.prosperityImage
        }
        let date = DateFormatter.dateSimple.string(from: expiredAt)
        let viewPlanAttributes: AttributeContainer = {
            var container = AttributeContainer()
            container.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            container.foregroundColor = .white
            return container
        }()
        if expiredAt.timeIntervalSinceNow < 0 {
            expirationLabel.text = R.string.localizable.expired_on(date)
            expirationLabel.textColor = R.color.error_red()
            viewPlanButton.configuration?.attributedTitle = AttributedString(
                R.string.localizable.renew_plan(),
                attributes: viewPlanAttributes
            )
        } else {
            expirationLabel.text = R.string.localizable.expires_on(date)
            expirationLabel.textColor = R.color.text_secondary()
            viewPlanButton.configuration?.attributedTitle = AttributedString(
                R.string.localizable.view_plan(),
                attributes: viewPlanAttributes
            )
        }
    }
    
    @IBAction func viewPlan(_ sender: Any) {
        delegate?.membershipCellDidSelectViewPlan(self)
    }
    
}
