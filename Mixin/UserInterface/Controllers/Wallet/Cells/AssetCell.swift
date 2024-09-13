import UIKit
import MixinServices

class AssetCell: ModernSelectedBackgroundCell {
    
    static let height: CGFloat = 74
    static let symbolAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.scaledFont(ofSize: 12, weight: .medium),
        .foregroundColor: UIColor.text
    ]
    
    @IBOutlet weak var assetIconView: BadgeIconView!
    @IBOutlet weak var balanceLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var fiatMoneyPriceLabel: UILabel!
    @IBOutlet weak var fiatMoneyBalanceLabel: UILabel!
    @IBOutlet weak var noFiatMoneyPriceIndicatorLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        balanceLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        symbolLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 3, right: 0)
        changeLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 4, right: 0)
        balanceLabel.setFont(scaledFor: .condensed(size: 19), adjustForContentSize: true)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func render(asset: TokenItem, attributedSymbol: NSAttributedString? = nil) {
        assetIconView.setIcon(token: asset)
        let balance: String
        if asset.decimalBalance.isZero {
            balance = zeroWith2Fractions
        } else {
            balance = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never) ?? ""
        }
        balanceLabel.text = balance
        if let attributedSymbol = attributedSymbol {
            symbolLabel.attributedText = attributedSymbol
        } else {
            symbolLabel.attributedText = NSAttributedString(string: asset.symbol, attributes: AssetCell.symbolAttributes)
        }
        if asset.decimalUSDPrice > 0 {
            changeLabel.text = asset.localizedUSDChange
            changeLabel.marketColor = .byValue(asset.decimalUSDChange)
            fiatMoneyPriceLabel.text = asset.localizedFiatMoneyPrice
            changeLabel.alpha = 1
            fiatMoneyPriceLabel.alpha = 1
            noFiatMoneyPriceIndicatorLabel.alpha = 0
        } else {
            changeLabel.text = R.string.localizable.na() // Just for layout guidance
            fiatMoneyPriceLabel.text = nil
            changeLabel.alpha = 0
            fiatMoneyPriceLabel.alpha = 0
            noFiatMoneyPriceIndicatorLabel.alpha = 1
        }
        fiatMoneyBalanceLabel.text = asset.localizedFiatMoneyBalance
    }
    
    func render(web3Token token: Web3Token) {
        assetIconView.setIcon(web3Token: token)
        let balance: String
        if token.balance == "0" {
            balance = zeroWith2Fractions
        } else {
            balance = CurrencyFormatter.localizedString(from: token.balance, format: .precision, sign: .never) ?? ""
        }
        balanceLabel.text = balance
        symbolLabel.attributedText = NSAttributedString(string: token.symbol, attributes: AssetCell.symbolAttributes)
        if token.decimalUSDPrice > 0 {
            changeLabel.text = token.localizedPercentChange
            changeLabel.marketColor = .byValue(token.decimalPercentChange)
            fiatMoneyPriceLabel.text = token.localizedFiatMoneyPrice
            changeLabel.alpha = 1
            fiatMoneyPriceLabel.alpha = 1
            noFiatMoneyPriceIndicatorLabel.alpha = 0
        } else {
            changeLabel.text = R.string.localizable.na() // Just for layout guidance
            fiatMoneyPriceLabel.text = nil
            changeLabel.alpha = 0
            fiatMoneyPriceLabel.alpha = 0
            noFiatMoneyPriceIndicatorLabel.alpha = 1
        }
        fiatMoneyBalanceLabel.text = token.localizedFiatMoneyBalance
    }
    
}
