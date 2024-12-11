import UIKit
import MixinServices

final class ExploreMarketTokenCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func exploreTokenMarketCellWantsToggleFavorite(_ cell: ExploreMarketTokenCell)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var favoriteActivityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var rankLabel: InsetLabel!
    @IBOutlet weak var marketCapLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var chartImageView: MarketColorTintedImageView!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    weak var delegate: Delegate?
    
    var isFavorited = false {
        didSet {
            let image = if isFavorited {
                R.image.market_favorited()
            } else {
                R.image.market_unfavorited()
            }
            favoriteButton.setImage(image, for: .normal)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(10, after: iconView)
        switch ScreenWidth.current {
        case .long:
            contentStackView.setCustomSpacing(40, after: priceLabel)
        case .medium:
            contentStackView.setCustomSpacing(20, after: priceLabel)
        case .short:
            contentStackView.setCustomSpacing(10, after: priceLabel)
        }
        rankLabel.font = .condensed(size: 12)
        rankLabel.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 0, right: 4)
        priceLabel.setFont(scaledFor: .systemFont(ofSize: 14, weight: .medium),
                           adjustForContentSize: true)
        favoriteActivityIndicatorView.style = .custom(diameter: 14, lineWidth: 2)
    }
    
    @IBAction func toggleFavorite(_ sender: Any) {
        delegate?.exploreTokenMarketCellWantsToggleFavorite(self)
    }
    
    func reloadData(market: FavorableMarket, changePeriod: Market.ChangePeriod) {
        symbolLabel.text = market.name
        iconView.setIcon(tokenIconURL: URL(string: market.iconURL))
        symbolLabel.text = market.symbol
        rankLabel.text = market.marketCapRank
        marketCapLabel.text = market.localizedMarketCap
        priceLabel.text = market.localizedPrice
        switch changePeriod {
        case .oneHour:
            chartImageView.sd_setImage(with: nil)
            changeLabel.text = nil
        case .twentyFourHours:
            chartImageView.sd_setImage(with: nil)
            changeLabel.text = nil
        case .sevenDays:
            chartImageView.sd_setImage(with: market.sparklineIn7DURL,
                                       placeholderImage: nil,
                                       options: .refreshCached,
                                       context: templateImageTransformingContext)
            changeLabel.text = market.localizedPriceChangePercentage7D
            let color: MarketColor = .byValue(market.decimalPriceChangePercentage7D)
            changeLabel.marketColor = color
            chartImageView.marketColor = color
        case .thirtyDays:
            chartImageView.sd_setImage(with: nil)
            changeLabel.text = nil
        }
        isFavorited = market.isFavorite
    }
    
}
