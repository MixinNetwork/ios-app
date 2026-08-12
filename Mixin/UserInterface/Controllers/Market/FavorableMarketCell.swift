import UIKit
import MixinServices

final class FavorableMarketCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func favorableMarketCellWantsToggleFavorite(_ cell: FavorableMarketCell)
    }
    
    @IBOutlet weak var favoriteButton: FavoriteButton!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var rankLabel: InsetLabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var chartImageView: MarketChartImageView!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    @IBOutlet weak var mainItemLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var priceWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var priceTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var chartWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var chartTrailingConstraint: NSLayoutConstraint!
    
    weak var delegate: Delegate?
    
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
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        chartImageView.prepareForReuse()
    }
    
    @IBAction func toggleFavorite(_ sender: Any) {
        delegate?.favorableMarketCellWantsToggleFavorite(self)
    }
    
    func reloadData(market: FavorableMarket, info: CryptoMarketDisplayInfo) {
        favoriteButton.setFavorite(market.isFavorite, animated: false)
        iconView.setIcon(tokenIconURL: URL(string: market.iconURL))
        symbolLabel.text = market.symbol
        switch info {
        case .volume:
            rankLabel.isHidden = true
            infoLabel.text = R.string.localizable.volume_label(market.prettyVolume)
        case .marketCap:
            rankLabel.text = market.marketCapRank
            rankLabel.isHidden = false
            infoLabel.text = market.localizedMarketCap
        }
        priceLabel.text = market.localizedPrice
        switch AppGroupUserDefaults.User.cryptoMarketChangePeriod {
        case .twentyFourHours:
            chartImageView.setChartImage(url: market.sparklineIn24HURL)
            changeLabel.text = market.localizedPriceChangePercentage24H
            let color: MarketColor = .byValue(market.decimalPriceChangePercentage24H)
            changeLabel.marketColor = color
            chartImageView.marketColor = color
        case .sevenDays:
            chartImageView.setChartImage(url: market.sparklineIn7DURL)
            changeLabel.text = market.localizedPriceChangePercentage7D
            let color: MarketColor = .byValue(market.decimalPriceChangePercentage7D)
            changeLabel.marketColor = color
            chartImageView.marketColor = color
        }
    }
    
}
