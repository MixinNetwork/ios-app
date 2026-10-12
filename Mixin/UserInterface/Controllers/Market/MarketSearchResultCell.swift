import UIKit
import MixinServices

final class MarketSearchResultCell: UICollectionViewCell {
    
    enum Subtitle {
        case name
        case volume
    }
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var leverageLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = SelectedCellBackgroundView()
        for label: UILabel in [priceLabel, subtitleLabel, changeLabel] {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        leverageLabel.font = UIFontMetrics.default.scaledFont(for: .condensed(size: 12))
        leverageLabel.layer.cornerRadius = 4
        leverageLabel.layer.masksToBounds = true
        leverageLabel.contentInset = UIEdgeInsets(top: 2, left: 3, bottom: 0, right: 3)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(market: Market, subtitle: Subtitle) {
        iconView.setIcon(market: market)
        symbolLabel.text = market.symbol
        leverageLabel.isHidden = true
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
        symbolLabel.text = market.tokenSymbol
        leverageLabel.isHidden = false
        leverageLabel.text = PerpetualLeverage.stringRepresentation(multiplier: market.leverage)
        priceLabel.text = market.localizedLastPrice
        subtitleLabel.text = R.string.localizable.volume_label(market.prettyVolume)
        changeLabel.text = market.changePercentage
        changeLabel.marketColor = .byValue(market.decimalChange)
    }
    
}
