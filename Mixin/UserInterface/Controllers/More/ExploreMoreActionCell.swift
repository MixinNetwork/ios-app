import UIKit
import SDWebImage
import MixinServices

final class ExploreMoreActionCell: UICollectionViewCell {
    
    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var badgeView: BadgeDotView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let cornerRadius: CGFloat = 8
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
        iconImageView.shouldCustomLoopCount = true
        iconImageView.animationRepeatCount = 3
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    func load(action: ExploreMoreAction) {
        switch action {
        case .buy:
            iconImageView.image = R.image.explore.buy()
            iconImageView.tintColor = R.color.text()
            titleLabel.text = R.string.localizable.buy()
            subtitleLabel.text = R.string.localizable.buy_crypto_with_cash()
            badgeView.isHidden = BadgeManager.shared.hasViewed(identifier: .buy)
        case .trade:
            iconImageView.image = R.image.explore.trade()
            iconImageView.tintColor = R.color.text()
            titleLabel.text = R.string.localizable.trade()
            subtitleLabel.text = R.string.localizable.trade_native_tokens()
            badgeView.isHidden = BadgeManager.shared.hasViewed(identifier: .trade)
        case .membership:
            iconImageView.image = R.image.explore.membership()
            iconImageView.tintColor = R.color.text()
            titleLabel.text = R.string.localizable.mixin_one()
            subtitleLabel.text = R.string.localizable.mixin_one_desc()
            badgeView.isHidden = BadgeManager.shared.hasViewed(identifier: .membership)
        case .referral:
            iconImageView.image = referralIconImage
            iconImageView.tintColor = nil
            titleLabel.text = R.string.localizable.referral()
            subtitleLabel.text = R.string.localizable.referral_description()
            badgeView.isHidden = BadgeManager.shared.hasViewed(identifier: .referral)
        case .linkDesktop:
            titleLabel.text = R.string.localizable.link_desktop()
            if AppGroupUserDefaults.Account.isDesktopLoggedIn {
                iconImageView.image = R.image.explore.desktop_logged_in()
                subtitleLabel.text = R.string.localizable.logined()
            } else {
                iconImageView.image = R.image.explore.link_desktop()
                iconImageView.tintColor = R.color.text()
                subtitleLabel.text = R.string.localizable.link_desktop_description()
            }
            badgeView.isHidden = true
        case .customerService:
            iconImageView.image = R.image.explore.customer_service()
            iconImageView.tintColor = R.color.text()
            titleLabel.text = R.string.localizable.contact_support()
            subtitleLabel.text = R.string.localizable.leave_message_to_team_mixin()
            badgeView.isHidden = true
        }
        accessibilityLabel = [titleLabel.text, subtitleLabel.text]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
    
}
