import UIKit
import MixinServices

final class PerpetualPositionValueCell: UICollectionViewCell {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var infoImageView: UIImageView!
    @IBOutlet weak var valueLabel: MarketColoredLabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var infoButton: UIButton!
    
    var presentTip: ((PerpetualPositionValueCell) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        valueLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .medium),
            adjustForContentSize: true
        )
    }
    
    func loadOpenPositions(value: PerpetualPositionValue?) {
        titleLabel.text = R.string.localizable.total_position_value()
        infoImageView.isHidden = true
        changeLabel.isHidden = false
        if let value {
            valueLabel.text = value.value
            changeLabel.text = value.change
        } else {
            valueLabel.text = "-"
            changeLabel.text = "-"
        }
        valueLabel.textColor = R.color.text_secondary()
        switch value?.state {
        case .gain:
            changeLabel.marketColor = .rising
        case .loss:
            changeLabel.marketColor = .falling
        case .neutral, .none:
            changeLabel.textColor = R.color.text_secondary()
        }
        infoButton.isEnabled = false
    }
    
    func loadClosedActivities(value: PerpetualPositionValue?) {
        titleLabel.text = R.string.localizable.total_realized_pnl()
        infoImageView.isHidden = false
        changeLabel.isHidden = true
        if let value {
            valueLabel.text = value.value
        } else {
            valueLabel.text = "-"
        }
        switch value?.state {
        case .gain:
            valueLabel.marketColor = .rising
        case .loss:
            valueLabel.marketColor = .falling
        case .neutral, .none:
            valueLabel.textColor = R.color.text_secondary()
        }
        infoButton.isEnabled = true
    }
    
    @IBAction func requestTip(_ sender: Any) {
        presentTip?(self)
    }
    
}
