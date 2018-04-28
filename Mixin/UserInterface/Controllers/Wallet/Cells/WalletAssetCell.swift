import UIKit

class WalletAssetCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_asset"
    static let cellHeight: CGFloat = 70

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var exchangeLabel: UILabel!
    @IBOutlet weak var blockchainImageView: CornerImageView!
    

    func render(asset: AssetItem) {
        nameLabel.text = asset.name
        balanceLabel.text = String(format: "%@ %@", asset.balance.formatBalance(), asset.symbol)
        exchangeLabel.text = asset.getUSDBalance()
        iconImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        if let chainIconUrl = asset.chainIconUrl {
            blockchainImageView.sd_setImage(with: URL(string: chainIconUrl))
            blockchainImageView.isHidden = false
        } else {
            blockchainImageView.isHidden = true
        }
    }

}
