import UIKit

final class WalletSearchRecentCell: UICollectionViewCell {
    
    enum IconSize {
        case small
        case medium
    }
    
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var apyLabel: InsetLabel!
    
    @IBOutlet weak var iconViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconViewTrailingConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderWidth = 1
        updateBorderColor()
        iconView.reportsNoIntrinsicContentSize = true
        iconView.badgeIconDiameter = 11
        iconView.badgeOutlineWidth = 1
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        apyLabel.setFont(scaledFor: .systemFont(ofSize: 12, weight: .medium), adjustForContentSize: true)
        apyLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        apyLabel.layer.cornerRadius = 4
        apyLabel.layer.masksToBounds = true
        apyLabel.textColor = R.color.market_green()
        apyLabel.backgroundColor = R.color.market_green()!.withAlphaComponent(0.1)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.cornerRadius = contentView.bounds.height / 2
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBorderColor()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
        apyLabel.isHidden = true
    }
    
    func layout(iconSize: IconSize) {
        switch iconSize {
        case .small:
            iconViewTopConstraint.constant = 6
            iconViewBottomConstraint.constant = 6
            iconViewLeadingConstraint.constant = 7
            iconViewTrailingConstraint.constant = 5
        case .medium:
            iconViewTopConstraint.constant = 5
            iconViewBottomConstraint.constant = 5
            iconViewLeadingConstraint.constant = 6
            iconViewTrailingConstraint.constant = 4
        }
    }
    
    private func updateBorderColor() {
        contentView.layer.borderColor = switch traitCollection.userInterfaceStyle {
        case .dark:
            UIColor.white.withAlphaComponent(0.06).cgColor
        case .light, .unspecified:
            UIColor.black.withAlphaComponent(0.06).cgColor
        @unknown default:
            UIColor.black.withAlphaComponent(0.06).cgColor
        }
    }
    
}
