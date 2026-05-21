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
        titleLabel.text = switch (viewModel.state, viewModel.side) {
        case (.opened, .long):
            R.string.localizable.opened_long()
        case (.opened, .short):
            R.string.localizable.opened_short()
        case (.closed, .long):
            R.string.localizable.closed_long()
        case (.closed, .short):
            R.string.localizable.closed_short()
        }
        valueLabel.text = viewModel.orderValueInToken
        switch viewModel.side {
        case .long:
            leverageLabel.color = .long
        case .short:
            leverageLabel.color = .short
        }
        leverageLabel.text = viewModel.leverage
        switch viewModel.state {
        case .opened:
            changeLabel.text = nil
        case let .closed(pnl, _):
            changeLabel.text = pnl.abbreviated
            changeLabel.marketColor = pnl.color
        }
    }
    
}
