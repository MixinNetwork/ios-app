import UIKit

final class PerpsMarketSelectorCategoryCell: UICollectionViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var category: MarketSubCategoryDisplay? {
        didSet {
            switch category {
            case .favorite:
                label.text = "Fav" // Layout with dynamic type
                label.alpha = 0
                imageView.image = R.image.market_unfavorited()!
                    .withRenderingMode(.alwaysTemplate)
            case .text(let text):
                label.text = text
                label.alpha = 1
                imageView.image = nil
            case nil:
                label.text = nil
                imageView.image = nil
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        var backgroundConfig = UIBackgroundConfiguration.clear()
        backgroundConfig.strokeWidth = 1
        if state.isSelected {
            label.textColor = R.color.theme()
            imageView.tintColor = R.color.theme()
            backgroundConfig.backgroundColor = R.color.background_quaternary()
            backgroundConfig.strokeColor = R.color.theme()
        } else {
            label.textColor = R.color.text_secondary()
            imageView.tintColor = R.color.icon_tint()
            backgroundConfig.backgroundColor = R.color.background()
            backgroundConfig.strokeColor = R.color.line()
        }
        backgroundConfig.cornerRadius = bounds.height / 2
        self.backgroundConfiguration = backgroundConfig
    }
    
}
