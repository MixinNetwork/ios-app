import UIKit

final class ExploreRecentSearchCell: UICollectionViewCell {
    
    @IBOutlet weak var tokenIconView: PlainTokenIconView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderWidth = 1
        updateBorderColor()
        contentView.snp.makeConstraints { make in
            // XXX: Otherwise it breaks out the layout width
            make.width.lessThanOrEqualTo(UIScreen.main.bounds.width - 40)
        }
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
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
        tokenIconView.prepareForReuse()
        avatarImageView.prepareForReuse()
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
