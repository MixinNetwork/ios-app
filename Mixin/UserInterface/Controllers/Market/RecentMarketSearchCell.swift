import UIKit

final class RecentMarketSearchCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var perpsLabel: InsetLabel!
    @IBOutlet weak var subtitleLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderWidth = 1
        updateBorderColor()
        iconView.reportsNoIntrinsicContentSize = true
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        perpsLabel.setFont(
            scaledFor: .systemFont(ofSize: 12, weight: .medium),
            adjustForContentSize: true
        )
        perpsLabel.layer.cornerRadius = 4
        perpsLabel.layer.masksToBounds = true
        perpsLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        perpsLabel.text = R.string.localizable.perp()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.cornerRadius = contentView.bounds.height / 2
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
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
