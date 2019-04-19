import UIKit

class AssetCell: UITableViewCell {
    
    static let height: CGFloat = 74
    static let balanceAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: "DINCondensed-Bold", size: 19)!,
        .foregroundColor: UIColor.darkText,
        .kern: 0.7
    ]
    static let symbolAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12, weight: .medium),
        .foregroundColor: UIColor.darkText
    ]
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var balanceLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var changeLabel: InsetLabel!
    @IBOutlet weak var usdPriceLabel: UILabel!
    @IBOutlet weak var usdBalanceLabel: UILabel!
    @IBOutlet weak var noUSDPriceIndicatorLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        balanceLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        symbolLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 3, right: 0)
        changeLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 4, right: 0)
        selectedBackgroundView = UIView(frame: bounds)
        selectedBackgroundView!.backgroundColor = .modernCellSelection
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func render(asset: AssetItem, attributedSymbol: NSAttributedString? = nil) {
        assetIconView.setIcon(asset: asset)
        let balance: String
        if asset.balance == "0" {
            balance = "0\(currentDecimalSeparator)00"
        } else {
            balance = CurrencyFormatter.localizedString(from: asset.balance, format: .pretty, sign: .never) ?? ""
        }
        balanceLabel.attributedText = NSAttributedString(string: balance, attributes: AssetCell.balanceAttributes)
        if let attributedSymbol = attributedSymbol {
            symbolLabel.attributedText = attributedSymbol
        } else {
            symbolLabel.attributedText = NSAttributedString(string: asset.symbol, attributes: AssetCell.symbolAttributes)
        }
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
