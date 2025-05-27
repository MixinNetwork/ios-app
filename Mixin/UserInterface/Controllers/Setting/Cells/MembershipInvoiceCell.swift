import UIKit
import SDWebImage
import MixinServices

final class MembershipInvoiceCell: UITableViewCell {

    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        statusLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    func load(order: MembershipOrder) {
        let title = switch order.transition {
        case .upgrade:
            R.string.localizable.invoice_upgrade_plan
        case .renew:
            R.string.localizable.invoice_renew_plan
        }
        switch order.after.knownCase {
        case .basic:
            iconImageView.image = R.image.membership_advance_large()
            titleLabel.text = title(R.string.localizable.membership_advance())
        case .standard:
            iconImageView.image = R.image.membership_elite_large()
            titleLabel.text = title(R.string.localizable.membership_elite())
        case .premium:
            iconImageView.image = UserBadgeIcon.prosperityImage(dimension: 32)
            titleLabel.text = title(R.string.localizable.membership_prosperity())
        case nil:
            iconImageView.image = nil
            titleLabel.text = nil
        }
        statusLabel.text = order.status.localizedDescription
        statusLabel.textColor = switch order.status.knownCase {
        case .initial:
            R.color.text_tertiary()
        case .paid:
            R.color.market_green()
        case .cancel, .expired, .failed, .none:
            R.color.market_red()
        }
    }
    
}
