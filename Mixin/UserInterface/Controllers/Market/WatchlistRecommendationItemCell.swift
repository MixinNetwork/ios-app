import UIKit
import MixinServices

final class WatchlistRecommendationItemCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var tagLabel: InsetLabel!
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
        tagLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        tagLabel.layer.cornerRadius = 4
        tagLabel.layer.masksToBounds = true
    }
    
    func loadCrypto(market: Market) {
        iconView.setIcon(market: market)
        symbolLabel.text = market.symbol
        tagLabel.isHidden = true
        infoLabel.text = market.localizedMarketCap
        infoLabel.textColor = R.color.text_tertiary()
    }
    
    func loadPerps(market: PerpetualMarket) {
        iconView.setIcon(urlString: market.iconURL)
        symbolLabel.text = market.tokenSymbol
        tagLabel.isHidden = false
        tagLabel.text = R.string.localizable.perp()
        infoLabel.text = market.changePercentage
        infoLabel.marketColor = .byValue(market.decimalChange)
    }
    
}
