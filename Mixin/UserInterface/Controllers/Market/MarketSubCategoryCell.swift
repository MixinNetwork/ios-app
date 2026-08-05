import UIKit

final class MarketSubCategoryCell: UICollectionViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var category: MarketSubCategoryDisplay? {
        didSet {
            switch category {
            case .favorite:
                label.text = nil
                imageView.image = R.image.market_unfavorited()!
                    .withRenderingMode(.alwaysTemplate)
            case .text(let text):
                label.text = text
                imageView.image = nil
            case nil:
                label.text = nil
                imageView.image = nil
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                label.textColor = R.color.theme()
                imageView.tintColor = R.color.theme()
            } else {
                label.textColor = R.color.text_tertiary()
                imageView.tintColor = R.color.icon_tint()
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
        if state.isSelected {
            backgroundConfig.backgroundColor = R.color.theme()?.withAlphaComponent(0.1)
        } else {
            backgroundConfig.backgroundColor = .clear
        }
        backgroundConfig.cornerRadius = bounds.height / 2
        self.backgroundConfiguration = backgroundConfig
    }
    
}
