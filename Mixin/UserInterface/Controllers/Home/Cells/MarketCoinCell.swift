import UIKit
import MixinServices

final class MarketCoinCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconImageView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var priceLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        for label in [nameLabel, changeLabel, priceLabel] {
            label!.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
    }
    
    func load(market: Market) {
        iconImageView.setIcon(market: market)
        symbolLabel.text = market.symbol
        nameLabel.text = market.name
        switch AppGroupUserDefaults.User.marketChangePeriod {
        case .twentyFourHours:
            changeLabel.text = market.localizedPriceChangePercentage24H
            changeLabel.marketColor = .byValue(market.decimalPriceChangePercentage24H)
        case .sevenDays:
            changeLabel.text = market.localizedPriceChangePercentage7D
            changeLabel.marketColor = .byValue(market.decimalPriceChangePercentage7D)
        }
        priceLabel.text = market.localizedPrice
    }
    
}
