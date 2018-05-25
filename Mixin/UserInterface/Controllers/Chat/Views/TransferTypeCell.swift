import UIKit

class TransferTypeCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_transfer_type"
    static let cellHeight: CGFloat = 96

    @IBOutlet weak var assetIconImageView: CornerImageView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var blockchainImageView: CornerImageView!
    
    func render(asset: AssetItem) {
        assetIconImageView.sd_setImage(with: URL(string :asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        symbolLabel.text = asset.symbol
        balanceLabel.text = asset.localizedBalance
        if let chainIconUrl = asset.chainIconUrl {
            blockchainImageView.sd_setImage(with: URL(string: chainIconUrl))
            blockchainImageView.isHidden = false
        } else {
            blockchainImageView.isHidden = true
        }
    }

}
