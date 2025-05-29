import UIKit
import SDWebImage
import MixinServices

final class MembershipOrderStatusCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconView: SDAnimatedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: TransactionStatusLabel!
    
    func load(order: MembershipOrder) {
        iconView.image = switch order.transition {
        case .upgrade(let plan), .renew(let plan):
            switch plan {
            case .basic:
                R.image.membership_advance_large()
            case .standard:
                R.image.membership_elite_large()
            case .premium:
                UserBadgeIcon.prosperityImage(dimension: 70)
            }
        case .buyStars:
            R.image.mixin_star()
        case .none:
            nil
        }
        switch order.transition {
        case .upgrade:
            titleLabel.text = R.string.localizable.upgrade_plan()
        case .renew:
            titleLabel.text = R.string.localizable.renew_plan()
        case .buyStars(let count):
            let attributedText = NSMutableAttributedString(
                string: "+\(count)",
                attributes: [
                    .foregroundColor: R.color.market_green()!,
                    .font: UIFont.condensed(size: 34),
                ]
            )
            let stars = NSAttributedString(
                string: R.string.localizable.stars(),
                attributes: [
                    .foregroundColor: R.color.text(),
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                ]
            )
            attributedText.append(stars)
            titleLabel.attributedText = attributedText
        case .none:
            titleLabel.text = nil
        }
        statusLabel.load(status: order.status)
    }
    
}
