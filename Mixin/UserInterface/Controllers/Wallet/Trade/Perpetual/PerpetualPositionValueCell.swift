import UIKit
import MixinServices

final class PerpetualPositionValueCell: UICollectionViewCell {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: MarketColoredLabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }
    
    func loadOpenPositions(value: PerpetualPositionValue?) {
        titleLabel.text = R.string.localizable.total_position_value()
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
    }
    
    func loadClosedPositions(value: PerpetualPositionValue?) {
        titleLabel.text = R.string.localizable.total_realized_pnl()
        if let value {
            valueLabel.text = value.value
            changeLabel.text = value.change
        } else {
            valueLabel.text = "-"
            changeLabel.text = "-"
        }
        switch value?.state {
        case .gain:
            valueLabel.marketColor = .rising
            changeLabel.marketColor = .rising
        case .loss:
            valueLabel.marketColor = .falling
            changeLabel.marketColor = .falling
        case .neutral, .none:
            valueLabel.textColor = R.color.text_secondary()
            changeLabel.textColor = R.color.text_secondary()
        }
    }
    
}
