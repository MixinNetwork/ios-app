import UIKit
import MixinServices

final class TradeSpotMarketCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let labels: [UILabel] = [volumeLabel, priceLabel, changeLabel]
        for label in labels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(market: FavorableMarket) {
        iconView.setIcon(market: market)
        symbolLabel.text = market.symbol
        volumeLabel.text = R.string.localizable.volume_label(market.prettyVolume)
        priceLabel.text = market.localizedPrice
        switch AppGroupUserDefaults.User.cryptoMarketChangePeriod {
        case .twentyFourHours:
            changeLabel.text = market.localizedPriceChangePercentage24H
            changeLabel.marketColor = .byValue(market.decimalPriceChangePercentage24H)
        case .sevenDays:
            changeLabel.text = market.localizedPriceChangePercentage7D
            changeLabel.marketColor = .byValue(market.decimalPriceChangePercentage7D)
        }
    }
    
}
