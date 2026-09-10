import UIKit
import MixinServices

final class MarketSearchResultCell: UICollectionViewCell {
    
    enum Subtitle {
        case name
        case volume
    }
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = SelectedCellBackgroundView()
        for label in [priceLabel, subtitleLabel, changeLabel] {
            label?.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(market: Market, subtitle: Subtitle) {
        iconView.setIcon(market: market)
        symbolLabel.text = market.symbol
        priceLabel.text = market.localizedPrice
        subtitleLabel.text = switch subtitle {
        case .name:
            market.name
        case .volume:
            R.string.localizable.volume_label(market.prettyVolume)
        }
        changeLabel.text = market.localizedPriceChangePercentage24H
        changeLabel.marketColor = .byValue(market.decimalPriceChangePercentage24H)
    }
    
    func load(market: PerpetualMarket) {
        iconView.setIcon(urlString: market.iconURL)
        symbolLabel.text = market.displaySymbol
        priceLabel.text = market.localizedPrice
        subtitleLabel.text = R.string.localizable.volume_label(market.prettyVolume)
        changeLabel.text = market.changePercentage
        changeLabel.marketColor = .byValue(market.decimalChange)
    }
    
}
