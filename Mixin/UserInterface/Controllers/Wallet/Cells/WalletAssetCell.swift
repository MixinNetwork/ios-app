import UIKit

class WalletAssetCell: UITableViewCell {
    
    static let height: CGFloat = 96
    static let balanceAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: "MixinCondensed-Regular", size: 24)!,
        .kern: 0.7
    ]
    
    @IBOutlet weak var cardView: ShadowedCardView!
    @IBOutlet weak var iconImageView: CornerImageView!
    @IBOutlet weak var chainImageView: CornerImageView!
    @IBOutlet weak var balanceLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var changeLabel: InsetLabel!
    @IBOutlet weak var usdPriceLabel: UILabel!
    @IBOutlet weak var usdBalanceLabel: UILabel!
    @IBOutlet weak var noUSDPriceIndicatorLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        balanceLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        symbolLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        changeLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        cardView.setHighlighted(selected, animated: animated)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        cardView.setHighlighted(highlighted, animated: animated)
    }
    
    func render(asset: AssetItem) {
        iconImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        if let chainIconUrl = asset.chainIconUrl {
            chainImageView.sd_setImage(with: URL(string: chainIconUrl))
            chainImageView.isHidden = false
        } else {
            chainImageView.isHidden = true
        }
        let balance = CurrencyFormatter.localizedString(from: asset.balance, format: .pretty, sign: .never) ?? ""
        balanceLabel.attributedText = NSAttributedString(string: balance, attributes: WalletAssetCell.balanceAttributes)
        symbolLabel.text = asset.symbol
        if asset.priceUsd.doubleValue > 0 {
            changeLabel.text = " \(asset.localizedUSDChange)%"
            if asset.changeUsd.doubleValue > 0 {
                changeLabel.textColor = .walletGreen
            } else {
                changeLabel.textColor = .walletRed
            }
            usdPriceLabel.text = "$\(asset.localizedPriceUsd)"
            changeLabel.alpha = 1
            usdPriceLabel.alpha = 1
            noUSDPriceIndicatorLabel.alpha = 0
        } else {
            changeLabel.text = Localized.WALLET_NO_PRICE // Just for layout guidance
            usdPriceLabel.text = nil
            changeLabel.alpha = 0
            usdPriceLabel.alpha = 0
            noUSDPriceIndicatorLabel.alpha = 1
        }
        usdBalanceLabel.text = asset.localizedUSDBalance
    }

}
