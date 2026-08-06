import UIKit
import MixinServices

final class FavorableMarketCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func favorableMarketCellWantsToggleFavorite(_ cell: FavorableMarketCell)
    }
    
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var favoriteActivityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var rankLabel: InsetLabel!
    @IBOutlet weak var marketCapLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var chartImageView: MarketColorTintedImageView!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    @IBOutlet weak var mainItemLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var priceWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var priceTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var chartWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var chartTrailingConstraint: NSLayoutConstraint!
    
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
        mainItemLeadingConstraint.constant = MarketLayout.mainItemLeadingMargin
        priceWidthConstraint.constant = MarketLayout.priceItemWidth
        priceTrailingConstraint.constant = MarketLayout.priceItemTrailingMargin
        chartWidthConstraint.constant = MarketLayout.changeItemWidth
        chartTrailingConstraint.constant = MarketLayout.changeItemTrailingMargin
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        rankLabel.font = .condensed(size: 12)
        rankLabel.contentInset = UIEdgeInsets(top: 2, left: 3, bottom: 0, right: 3)
        priceLabel.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .medium),
            adjustForContentSize: true
        )
        favoriteActivityIndicatorView.style = .custom(diameter: 14, lineWidth: 2)
    }
    
    @IBAction func toggleFavorite(_ sender: Any) {
        delegate?.favorableMarketCellWantsToggleFavorite(self)
    }
    
    func reloadData(market: FavorableMarket) {
        iconView.setIcon(tokenIconURL: URL(string: market.iconURL))
        symbolLabel.text = market.symbol
        rankLabel.text = market.marketCapRank
        marketCapLabel.text = market.localizedMarketCap
        priceLabel.text = market.localizedPrice
        switch AppGroupUserDefaults.User.cryptoMarketChangePeriod {
        case .twentyFourHours:
            chartImageView.sd_setImage(
                with: market.sparklineIn24HURL,
                placeholderImage: nil,
                options: .refreshCached,
                context: templateImageTransformingContext
            )
            changeLabel.text = market.localizedPriceChangePercentage24H
            let color: MarketColor = .byValue(market.decimalPriceChangePercentage24H)
            changeLabel.marketColor = color
            chartImageView.marketColor = color
        case .sevenDays:
            chartImageView.sd_setImage(
                with: market.sparklineIn7DURL,
                placeholderImage: nil,
                options: .refreshCached,
                context: templateImageTransformingContext
            )
            changeLabel.text = market.localizedPriceChangePercentage7D
            let color: MarketColor = .byValue(market.decimalPriceChangePercentage7D)
            changeLabel.marketColor = color
            chartImageView.marketColor = color
        }
        isFavorited = market.isFavorite
    }
    
}
