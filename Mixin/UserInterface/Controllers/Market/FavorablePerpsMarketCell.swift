import UIKit
import MixinServices

final class FavorablePerpsMarketCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func favorablePerpsMarketCellWantsToggleFavorite(_ cell: FavorablePerpsMarketCell)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var favoriteActivityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var tagLabel: InsetLabel!
    @IBOutlet weak var marketCapLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
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
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        tagLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        tagLabel.text = R.string.localizable.perp()
        tagLabel.layer.cornerRadius = 4
        tagLabel.layer.masksToBounds = true
        priceLabel.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .medium),
            adjustForContentSize: true
        )
        changeLabel.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .medium),
            adjustForContentSize: true
        )
        favoriteActivityIndicatorView.style = .custom(diameter: 14, lineWidth: 2)
    }
    
    @IBAction func toggleFavorite(_ sender: Any) {
        delegate?.favorablePerpsMarketCellWantsToggleFavorite(self)
    }
    
    func reloadData(market: FavorablePerpetualMarket) {
        symbolLabel.text = market.tokenSymbol
        iconView.setIcon(tokenIconURL: URL(string: market.iconURL))
        marketCapLabel.text = market.prettyVolume
        priceLabel.text = market.localizedPrice
        changeLabel.text = market.changePercentage
        changeLabel.marketColor = .byValue(market.decimalChange)
        isFavorited = market.isFavorite
    }
    
}
