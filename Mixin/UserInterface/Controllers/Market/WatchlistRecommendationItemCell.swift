import UIKit
import MixinServices

final class WatchlistRecommendationItemCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var leverageLabel: InsetLabel!
    @IBOutlet weak var infoLabel: MarketColoredLabel!
    @IBOutlet weak var selectionImageView: UIImageView!
    
    override var isSelected: Bool {
        didSet {
            selectionImageView.image = isSelected ? R.image.ic_selected() : R.image.ic_deselected()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderColor = R.color.line()!.cgColor
        contentView.layer.borderWidth = 1
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        leverageLabel.contentInset = UIEdgeInsets(top: 2, left: 3, bottom: 0, right: 3)
        leverageLabel.layer.cornerRadius = 4
        leverageLabel.layer.masksToBounds = true
        leverageLabel.font = UIFontMetrics.default.scaledFont(
            for: .condensed(size: 12)
        )
    }
    
    func loadCrypto(market: Market) {
        iconView.setIcon(market: market)
        symbolLabel.text = market.symbol
        leverageLabel.isHidden = true
        infoLabel.text = market.localizedMarketCap
        infoLabel.textColor = R.color.text_tertiary()
    }
    
    func loadPerps(market: PerpetualMarket) {
        iconView.setIcon(urlString: market.iconURL)
        symbolLabel.text = market.tokenSymbol
        leverageLabel.isHidden = false
        leverageLabel.text = PerpetualLeverage.stringRepresentation(multiplier: market.leverage)
        infoLabel.text = market.changePercentage
        infoLabel.marketColor = .byValue(market.decimalChange)
    }
    
}
