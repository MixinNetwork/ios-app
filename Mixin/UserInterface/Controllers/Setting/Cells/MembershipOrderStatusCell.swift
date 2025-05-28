import UIKit
import SDWebImage
import MixinServices

final class MembershipOrderStatusCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconView: SDAnimatedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: TransactionStatusLabel!
    
    func load(order: MembershipOrder) {
        iconView.image = switch order.after.knownCase {
        case .basic:
            R.image.membership_advance_large()
        case .standard:
            R.image.membership_elite_large()
        case .premium:
            UserBadgeIcon.prosperityImage(dimension: 70)
        case nil:
            nil
        }
        titleLabel.text = switch order.transition {
        case .upgrade:
            R.string.localizable.upgrade_plan()
        case .renew:
            R.string.localizable.renew_plan()
        }
        statusLabel.load(status: order.status)
    }
    
}
