import UIKit
import MixinServices

final class FavorablePerpsMarketCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func favorablePerpsMarketCellWantsToggleFavorite(_ cell: FavorablePerpsMarketCell)
    }
    
    enum Tag {
        case leverage
        case identity
    }
    
    @IBOutlet weak var favoriteButton: FavoriteButton!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var tagLabel: InsetLabel!
    @IBOutlet weak var infoLabel: UILabel!
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
    
    func reloadData(market: FavorablePerpetualMarket, tag: Tag) {
        favoriteButton.setFavorite(market.isFavorite, animated: false)
        symbolLabel.text = market.tokenSymbol
        iconView.setIcon(tokenIconURL: URL(string: market.iconURL))
        infoLabel.text = R.string.localizable.volume_label(market.prettyVolume)
        priceLabel.text = market.localizedPrice
        changeLabel.text = market.changePercentage
        changeLabel.marketColor = .byValue(market.decimalChange)
        switch tag {
        case .leverage:
            tagLabel.font = UIFontMetrics.default.scaledFont(for: .condensed(size: 12))
            tagLabel.contentInset = UIEdgeInsets(top: 2, left: 3, bottom: 0, right: 3)
            tagLabel.text = PerpetualLeverage.stringRepresentation(multiplier: market.leverage)
        case .identity:
            tagLabel.font = .preferredFont(forTextStyle: .caption1)
            tagLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
            tagLabel.text = R.string.localizable.perp()
        }
    }
    
}
