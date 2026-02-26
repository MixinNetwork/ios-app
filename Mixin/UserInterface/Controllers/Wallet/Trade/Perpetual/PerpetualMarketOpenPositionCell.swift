import UIKit

final class PerpetualMarketOpenPositionCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var pnlTitleLabel: UILabel!
    @IBOutlet weak var pnlContentLabel: UILabel!
    
    @IBOutlet weak var directionTitleLabel: UILabel!
    @IBOutlet weak var directionSideLabel: MarketColoredLabel!
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
        pnlContentLabel.text = viewModel.pnl?.count
        directionTitleLabel.text = "DIRECTION"
        switch viewModel.leverage {
        case .long(let value):
            directionSideLabel.text = "Long"
            directionLeverageLabel.text = value
        case .short(let value):
            directionSideLabel.text = "Short"
            directionLeverageLabel.text = value
        }
        orderValueTitleLabel.text = "ORDER VALUE"
        orderValueContentLabel.text = "Under Construction"
        amountTitleLabel.text = "AMOUNT"
        amountContentLabel.text = "Under Construction"
        entryPriceTitleLabel.text = "ENTRY PRICE"
        entryPriceContentLabel.text = viewModel.entryPrice
        liquidationPriceTitleLabel.text = "LIQUIDATION PRICE"
        entryPriceContentLabel.text = "Under Construction"
    }
    
}
