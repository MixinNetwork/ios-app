import UIKit

final class PerpetualMarketCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var leverageLabel: LeverageLabel!
    @IBOutlet weak var autoClosingLabel: InsetLabel!
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
        autoClosingLabel.setFont(
            scaledFor: .systemFont(ofSize: 12, weight: .medium),
            adjustForContentSize: true
        )
        autoClosingLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        autoClosingLabel.layer.cornerRadius = 4
        autoClosingLabel.layer.masksToBounds = true
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
        autoClosingLabel.isHidden = true
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
        leverageLabel.text = viewModel.leverage
        switch (viewModel.takeProfitPrice, viewModel.stopLossPrice) {
        case (.some, .none):
            autoClosingLabel.text = R.string.localizable.take_profit_label()
            autoClosingLabel.isHidden = false
        case (.none, .some):
            autoClosingLabel.text = R.string.localizable.stop_loss_label()
            autoClosingLabel.isHidden = false
        case (.some, .some):
            autoClosingLabel.text = R.string.localizable.take_profit_stop_loss_label()
            autoClosingLabel.isHidden = false
        case (.none, .none):
            autoClosingLabel.isHidden = true
        }
        topRightLabel.text = viewModel.margin
        volumeLabel.text = viewModel.orderValueInToken
        changeLabel.text = viewModel.pnlWithROE
        changeLabel.marketColor = viewModel.pnlColor
    }
    
}
