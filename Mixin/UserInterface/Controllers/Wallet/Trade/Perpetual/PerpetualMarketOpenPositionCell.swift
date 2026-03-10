import UIKit

final class PerpetualMarketOpenPositionCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var pnlTitleLabel: UILabel!
    @IBOutlet weak var pnlContentLabel: MarketColoredLabel!
    
    @IBOutlet weak var directionTitleLabel: UILabel!
    @IBOutlet weak var directionSideLabel: UILabel!
    @IBOutlet weak var directionLeverageLabel: UILabel!
    
    @IBOutlet weak var orderValueTitleLabel: UILabel!
    @IBOutlet weak var orderValueContentLabel: UILabel!
    
    @IBOutlet weak var amountTitleLabel: UILabel!
    @IBOutlet weak var amountContentLabel: UILabel!
    
    @IBOutlet weak var entryPriceTitleLabel: UILabel!
    @IBOutlet weak var entryPriceContentLabel: UILabel!
    
    @IBOutlet weak var liquidationPriceTitleLabel: UILabel!
    @IBOutlet weak var liquidationPriceContentLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        for label: UILabel in [pnlContentLabel, directionLeverageLabel] {
            label.setFont(
                scaledFor: .systemFont(ofSize: 14, weight: .medium),
                adjustForContentSize: true
            )
        }
        let contentLabels: [UILabel] = [
            orderValueContentLabel,
            amountContentLabel,
            entryPriceContentLabel,
            liquidationPriceContentLabel,
        ]
        for label in contentLabels {
            label.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
        }
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        titleLabel.text = "Open Position"
        pnlTitleLabel.text = "PNL"
        pnlContentLabel.text = viewModel.pnl
        pnlContentLabel.marketColor = viewModel.pnlColor
        directionTitleLabel.text = "DIRECTION"
        switch viewModel.leverage {
        case .long(let value):
            directionSideLabel.text = R.string.localizable.long()
            directionSideLabel.backgroundColor = MarketColor.rising.uiColor
            directionLeverageLabel.text = value
        case .short(let value):
            directionSideLabel.text = R.string.localizable.short()
            directionSideLabel.backgroundColor = MarketColor.falling.uiColor
            directionLeverageLabel.text = value
        }
        orderValueTitleLabel.text = "ORDER VALUE"
        orderValueContentLabel.text = viewModel.orderValueInToken
        amountTitleLabel.text = R.string.localizable.amount().uppercased()
        amountContentLabel.text = viewModel.orderValueInFiatMoney
        entryPriceTitleLabel.text = "ENTRY PRICE"
        entryPriceContentLabel.text = viewModel.entryPrice
        liquidationPriceTitleLabel.text = "LIQUIDATION PRICE"
        liquidationPriceContentLabel.text = viewModel.liquidationPrice
    }
    
}
