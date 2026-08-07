import UIKit
import MixinServices

final class FavorablePerpsMarketCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func favorablePerpsMarketCellWantsToggleFavorite(_ cell: FavorablePerpsMarketCell)
    }
    
    @IBOutlet weak var favoriteButton: FavoriteButton!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var tagLabel: InsetLabel!
    @IBOutlet weak var marketCapLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    @IBOutlet weak var mainItemLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var priceWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var priceTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var changeWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var changeTrailingConstraint: NSLayoutConstraint!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        mainItemLeadingConstraint.constant = MarketLayout.mainItemLeadingMargin
        priceWidthConstraint.constant = MarketLayout.priceItemWidth
        priceTrailingConstraint.constant = MarketLayout.priceItemTrailingMargin
        changeWidthConstraint.constant = MarketLayout.changeItemWidth
        changeTrailingConstraint.constant = MarketLayout.changeItemTrailingMargin
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
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    @IBAction func toggleFavorite(_ sender: Any) {
        delegate?.favorablePerpsMarketCellWantsToggleFavorite(self)
    }
    
    func reloadData(market: FavorablePerpetualMarket) {
        favoriteButton.setFavorite(market.isFavorite, animated: false)
        symbolLabel.text = market.tokenSymbol
        iconView.setIcon(tokenIconURL: URL(string: market.iconURL))
        marketCapLabel.text = market.prettyVolume
        priceLabel.text = market.localizedPrice
        changeLabel.text = market.changePercentage
        changeLabel.marketColor = .byValue(market.decimalChange)
    }
    
}
