import UIKit
import MixinServices

final class TradeSpotMarketCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var changeLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        changeLabel.contentInset = UIEdgeInsets(top: 3, left: 3, bottom: 1, right: 3)
        changeLabel.layer.cornerRadius = 4
        changeLabel.layer.masksToBounds = true
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        changeLabel.setFont(
            scaledFor: .monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            adjustForContentSize: true
        )
    }
    
    func load(market: Market) {
        iconView.setIcon(market: market)
        changeLabel.text = market.localizedPriceChangePercentage24H
        changeLabel.backgroundColor = market.decimalPriceChangePercentage24H >= 0
        ? MarketColor.rising.uiColor
        : MarketColor.falling.uiColor
        symbolLabel.text = market.symbol
        priceLabel.text = market.shortPrice
    }
    
}
