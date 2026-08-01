import UIKit

final class MarketSubCategoryCell: UICollectionViewCell {
    
    @IBOutlet weak var label: UILabel!
    
    override var isSelected: Bool {
        didSet {
            label.textColor = isSelected ? R.color.theme() : R.color.text_tertiary()
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
