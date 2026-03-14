import UIKit

final class PerpetualClosedPositionCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var leverageLabel: LeverageLabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        leverageLabel.setFont(
            scaledFor: .condensed(size: 12),
            adjustForContentSize: true
        )
        for label: UILabel in [valueLabel, changeLabel] {
            label.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        titleLabel.text = viewModel.directionWithSymbol
        switch viewModel.side {
        case .long:
            leverageLabel.color = .long
        case .short:
            leverageLabel.color = .short
        }
        leverageLabel.text = viewModel.leverageMultiplier
        valueLabel.text = viewModel.orderValueInToken
        changeLabel.text = viewModel.pnl
        changeLabel.marketColor = viewModel.pnlColor
    }
    
}
