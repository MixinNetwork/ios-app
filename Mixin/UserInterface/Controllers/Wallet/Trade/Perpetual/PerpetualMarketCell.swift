import UIKit

final class PerpetualMarketCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var leverageLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        leverageLabel.layer.cornerRadius = 4
        leverageLabel.layer.masksToBounds = true
        leverageLabel.contentInset = UIEdgeInsets(top: 2, left: 3, bottom: 0, right: 3)
        leverageLabel.setFont(
            scaledFor: .condensed(size: 12),
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
            leverageLabel.backgroundColor = MarketColor.rising.uiColor.withAlphaComponent(0.3)
            leverageLabel.textColor = MarketColor.rising.uiColor
        case .short(let value):
            leverageLabel.text = value
            leverageLabel.backgroundColor = MarketColor.falling.uiColor.withAlphaComponent(0.3)
            leverageLabel.textColor = MarketColor.falling.uiColor
        }
        priceLabel.text = viewModel.orderValueInFiatMoney
        volumeLabel.text = viewModel.orderValueInToken
        changeLabel.text = "Under Construction"
        changeLabel.marketColor = .falling
    }
    
}
