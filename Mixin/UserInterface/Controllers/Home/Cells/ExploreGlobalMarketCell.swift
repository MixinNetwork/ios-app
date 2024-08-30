import UIKit

final class ExploreGlobalMarketCell: UICollectionViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var primaryLabel: UILabel!
    @IBOutlet weak var secondaryLabel: UILabel!
    
    private let backgroundLayer = CAGradientLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundLayer.cornerRadius = 16
        backgroundLayer.masksToBounds = true
        contentView.layer.insertSublayer(backgroundLayer, at: 0)
        updateBackgroundColors()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.performWithoutAnimation {
            backgroundLayer.frame = contentView.bounds
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundColors()
        }
    }
    
    private func updateBackgroundColors() {
        switch traitCollection.userInterfaceStyle {
        case .dark:
            backgroundLayer.colors = [
                UIColor(displayP3RgbValue: 0x40444A).cgColor,
                UIColor(displayP3RgbValue: 0x3B3F44).cgColor,
            ]
        case .unspecified, .light:
            fallthrough
        @unknown default:
            backgroundLayer.colors = [
                UIColor(displayP3RgbValue: 0xF6F7FA).cgColor,
                UIColor(displayP3RgbValue: 0xEEF0F3).cgColor,
            ]
        }
    }
    
}
