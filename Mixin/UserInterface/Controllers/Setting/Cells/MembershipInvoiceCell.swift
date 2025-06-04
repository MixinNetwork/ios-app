import UIKit
import SDWebImage
import MixinServices

final class MembershipInvoiceCell: UITableViewCell {

    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var starsCountLabel: UILabel!
    @IBOutlet weak var starsUnitLabel: InsetLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        statusLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        starsCountLabel.setFont(
            scaledFor: .condensed(size: 19),
            adjustForContentSize: true
        )
        starsUnitLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 2, right: 0)
    }
    
    func load(order: MembershipOrder) {
        switch order.transition {
        case .upgrade(let plan):
            let title = R.string.localizable.invoice_upgrade_plan
            switch plan {
            case .basic:
                iconImageView.image = R.image.membership_advance_large()
                titleLabel.text = title(R.string.localizable.membership_advance())
            case .standard:
                iconImageView.image = R.image.membership_elite_large()
                titleLabel.text = title(R.string.localizable.membership_elite())
            case .premium:
                iconImageView.image = UserBadgeIcon.largeProsperityImage
                titleLabel.text = title(R.string.localizable.membership_prosperity())
            }
        case .renew(let plan):
            let title = R.string.localizable.invoice_renew_plan
            switch plan {
            case .basic:
                iconImageView.image = R.image.membership_advance_large()
                titleLabel.text = title(R.string.localizable.membership_advance())
            case .standard:
                iconImageView.image = R.image.membership_elite_large()
                titleLabel.text = title(R.string.localizable.membership_elite())
            case .premium:
                iconImageView.image = UserBadgeIcon.largeProsperityImage
                titleLabel.text = title(R.string.localizable.membership_prosperity())
            }
        case .buyStars:
            iconImageView.image = R.image.mixin_star()
            titleLabel.text = R.string.localizable.buy_stars()
        case .none:
            iconImageView.image = nil
            titleLabel.text = nil
        }
        statusLabel.text = order.status.localizedDescription
        statusLabel.textColor = switch order.status.knownCase {
        case .initial:
            R.color.text_tertiary()
        case .paid:
            R.color.market_green()
        case .cancel, .expired, .failed, .refund, .none:
            R.color.market_red()
        }
        switch order.status.knownCase {
        case .paid:
            starsCountLabel.text = "+\(order.transactionsQuantity)"
            starsUnitLabel.text = if order.transactionsQuantity == 1 {
                R.string.localizable.star()
            } else {
                R.string.localizable.stars()
            }
        default:
            starsCountLabel.text = nil
            starsUnitLabel.text = nil
        }
    }
    
}
