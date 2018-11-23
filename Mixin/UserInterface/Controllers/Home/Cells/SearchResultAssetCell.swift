import UIKit

class SearchResultAssetCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_asset"
    static let cellHeight: CGFloat = 70

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var exchangeLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var blockchainImageView: CornerImageView!
    
    func render(asset: AssetItem) {
        balanceLabel.text = CurrencyFormatter.localizedString(from: asset.balance, format: .pretty, sign: .never, symbol: .custom(asset.symbol))
        exchangeLabel.text = asset.localizedUSDBalance
        iconImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        if let chainIconUrl = asset.chainIconUrl {
            blockchainImageView.sd_setImage(with: URL(string: chainIconUrl))
            blockchainImageView.isHidden = false
        } else {
            blockchainImageView.isHidden = true
        }

        if asset.priceUsd.doubleValue > 0 {
            priceLabel.text = "$\(asset.localizedPriceUsd)"
            priceChangeLabel.text = "\(asset.localizedUSDChange)%"
            if asset.changeUsd.doubleValue > 0 {
                 priceChangeLabel.textColor = .walletGreen
            } else {
                priceChangeLabel.textColor = .walletRed
            }
        } else {
            priceLabel.text = Localized.WALLET_NO_PRICE
            priceChangeLabel.text = ""
        }
    }

}
