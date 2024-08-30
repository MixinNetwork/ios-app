import UIKit
import MixinServices

final class Web3TokenMarketCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func web3TokenMarketCellWantsToggleFavorite(_ cell: Web3TokenMarketCell)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var favoriteActivityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var rankLabel: InsetLabel!
    @IBOutlet weak var marketCapLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var chartImageView: UIImageView!
    @IBOutlet weak var changeLabel: UILabel!
    
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
        contentStackView.setCustomSpacing(24, after: priceLabel)
        rankLabel.font = .condensed(size: 12)
        rankLabel.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 0, right: 4)
        priceLabel.setFont(scaledFor: .systemFont(ofSize: 14, weight: .medium),
                           adjustForContentSize: true)
        
    }
    
    @IBAction func toggleFavorite(_ sender: Any) {
        delegate?.web3TokenMarketCellWantsToggleFavorite(self)
    }
    
    func reloadData(market: FavorableMarket) {
        symbolLabel.text = market.name
        iconView.setIcon(tokenIconURL: URL(string: market.iconURL))
        symbolLabel.text = market.symbol
        rankLabel.text = market.marketCapRank
        marketCapLabel.text = market.localizedMarketCap
        priceLabel.text = market.localizedPrice
        chartImageView.sd_setImage(with: market.chartImageURL)
        changeLabel.text = market.localizedChange
        if market.decimalChangePercentage >= 0 {
            changeLabel.textColor = .priceRising
        } else {
            changeLabel.textColor = .priceFalling
        }
        isFavorited = market.isFavorite
    }
    
}
