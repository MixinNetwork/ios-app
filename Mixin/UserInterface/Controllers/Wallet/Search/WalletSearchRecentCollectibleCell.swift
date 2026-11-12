import UIKit

final class WalletSearchRecentCollectibleCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: InscriptionIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderWidth = 1
        updateBorderColor()
        iconView.layer.cornerRadius = 8
        iconView.reportsNoIntrinsicContentSize = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
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
