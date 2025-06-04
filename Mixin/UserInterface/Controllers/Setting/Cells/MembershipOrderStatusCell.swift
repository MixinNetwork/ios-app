import UIKit
import SDWebImage
import MixinServices

final class MembershipOrderStatusCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func membershipOrderStatusCellWantsToCancel(_ cell: MembershipOrderStatusCell)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconView: SDAnimatedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: TransactionStatusLabel!
    
    weak var delegate: Delegate?
    
    private weak var pendingOrderActionView: UIStackView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(20, after: statusLabel)
    }
    
    func load(order: MembershipOrder) {
        iconView.image = switch order.transition {
        case .upgrade(let plan), .renew(let plan):
            switch plan {
            case .basic:
                R.image.membership_advance_large()
            case .standard:
                R.image.membership_elite_large()
            case .premium:
                UserBadgeIcon.largeProsperityImage
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
                    .foregroundColor: R.color.text()!,
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                ]
            )
            attributedText.append(stars)
            titleLabel.attributedText = attributedText
        case .none:
            titleLabel.text = nil
        }
        statusLabel.load(status: order.status)
        switch order.status.knownCase {
        case .initial:
            if pendingOrderActionView == nil {
                let label = UILabel()
                label.textColor = R.color.text_secondary()
                label.text = R.string.localizable.verifying_payment_description()
                label.numberOfLines = 0
                label.textAlignment = .center
                let button = UIButton(type: .system)
                button.setTitle(R.string.localizable.not_paid(), for: .normal)
                button.setTitleColor(R.color.theme(), for: .normal)
                button.addTarget(self, action: #selector(cancelOrder(_:)), for: .touchUpInside)
                let stackView = UIStackView(arrangedSubviews: [label, button])
                stackView.axis = .vertical
                stackView.spacing = 4
                contentStackView.addArrangedSubview(stackView)
                pendingOrderActionView = stackView
            }
        default:
            pendingOrderActionView?.removeFromSuperview()
        }
    }
    
    @objc private func cancelOrder(_ sender: Any) {
        delegate?.membershipOrderStatusCellWantsToCancel(self)
    }
    
}
