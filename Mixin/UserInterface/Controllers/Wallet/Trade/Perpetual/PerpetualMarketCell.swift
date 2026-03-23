import UIKit

final class PerpetualMarketCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var leverageLabel: LeverageLabel!
    @IBOutlet weak var topRightLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let subtitleLabels: [UILabel] = [
            topRightLabel,
            volumeLabel,
            changeLabel
        ]
        for label in subtitleLabels {
            label.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
        }
        leverageLabel.setFont(
            scaledFor: .condensed(size: 12),
            adjustForContentSize: true
        )
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualMarketViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        symbolLabel.text = viewModel.market.tokenSymbol
        leverageLabel.text = viewModel.leverage
        leverageLabel.color = .neutral
        topRightLabel.text = viewModel.price
        volumeLabel.text = R.string.localizable.volume_label(viewModel.volume)
        changeLabel.text = viewModel.change
        changeLabel.marketColor = viewModel.changeColor
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        symbolLabel.text = viewModel.directionWithSymbol
        switch viewModel.side {
        case .long:
            leverageLabel.color = .long
        case .short:
            leverageLabel.color = .short
        }
        leverageLabel.text = viewModel.leverageMultiplier
        topRightLabel.text = viewModel.margin
        volumeLabel.text = viewModel.orderValueInToken
        changeLabel.text = if let roe = viewModel.roe {
            viewModel.pnl + " (" + roe + ")"
        } else {
            viewModel.pnl
        }
        changeLabel.marketColor = viewModel.pnlColor
    }
    
}
