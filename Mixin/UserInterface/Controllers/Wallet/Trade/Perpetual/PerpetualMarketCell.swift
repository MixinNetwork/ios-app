import UIKit

final class PerpetualMarketCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var leverageLabel: LeverageLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        priceLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualMarketViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        symbolLabel.text = viewModel.symbol
        leverageLabel.text = viewModel.leverage
        leverageLabel.color = .neutral
        priceLabel.text = viewModel.price
        volumeLabel.text = viewModel.volume
        changeLabel.text = viewModel.change
        changeLabel.marketColor = viewModel.changeColor
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        symbolLabel.text = viewModel.directionWithSymbol
        switch viewModel.leverage {
        case .long(let value):
            leverageLabel.text = value
            leverageLabel.color = .long
        case .short(let value):
            leverageLabel.text = value
            leverageLabel.color = .short
        }
        priceLabel.text = viewModel.orderValueInFiatMoney
        volumeLabel.text = viewModel.orderValueInToken
        changeLabel.text = "Under Construction"
        changeLabel.marketColor = .falling
    }
    
}
