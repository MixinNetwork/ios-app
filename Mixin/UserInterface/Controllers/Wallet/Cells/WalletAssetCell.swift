import UIKit

class WalletAssetCell: UITableViewCell {
    
    static let height: CGFloat = 90
    
    @IBOutlet weak var iconImageView: CornerImageView!
    @IBOutlet weak var chainImageView: CornerImageView!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet weak var usdPriceLabel: UILabel!
    @IBOutlet weak var usdBalanceLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
    }
    
    func render(asset: AssetItem) {
        iconImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        if let chainIconUrl = asset.chainIconUrl {
            chainImageView.sd_setImage(with: URL(string: chainIconUrl))
            chainImageView.isHidden = false
        } else {
            chainImageView.isHidden = true
        }
        balanceLabel.text = CurrencyFormatter.localizedString(from: asset.balance, format: .pretty, sign: .never)
        symbolLabel.text = asset.symbol
        if asset.priceUsd.doubleValue > 0 {
            changeLabel.text = "\(asset.localizedUSDChange)%"
            if asset.changeUsd.doubleValue > 0 {
                changeLabel.textColor = .walletGreen
            } else {
                changeLabel.textColor = .walletRed
            }
            usdPriceLabel.text = "$\(asset.localizedPriceUsd)"
        } else {
            changeLabel.text = ""
            usdPriceLabel.text = Localized.WALLET_NO_PRICE
        }
        usdBalanceLabel.text = asset.localizedUSDBalance
    }

}
