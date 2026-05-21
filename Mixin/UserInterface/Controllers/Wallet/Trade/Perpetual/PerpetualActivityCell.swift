import UIKit

final class PerpetualActivityCell: UICollectionViewCell {
    
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
        leverageLabel.text = viewModel.leverage
        valueLabel.text = viewModel.orderValueInToken
        leverageLabel.color = .neutral
        changeLabel.text = R.string.localizable.perp_state_opening()
        changeLabel.textColor = R.color.text_tertiary()
    }
    
    func load(viewModel: PerpetualActivityViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        titleLabel.text = viewModel.title
        valueLabel.text = viewModel.orderValueInToken
        switch viewModel.side {
        case .long:
            leverageLabel.color = .long
        case .short:
            leverageLabel.color = .short
        }
        leverageLabel.text = viewModel.leverage
        switch viewModel.type {
        case .open, .increase:
            changeLabel.text = nil
        case let .close(pnl, _):
            changeLabel.text = pnl.aggregated
            changeLabel.marketColor = pnl.color
        }
    }
    
}
