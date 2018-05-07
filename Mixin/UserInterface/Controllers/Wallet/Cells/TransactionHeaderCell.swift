import UIKit
import SDWebImage

class TransactionHeaderCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_transation_header"
    static let cellHeight: CGFloat = 160

    @IBOutlet weak var assetImageView: AvatarImageView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var exchangeLabel: UILabel!
    @IBOutlet weak var blockchainImageView: CornerImageView!

    func render(asset: AssetItem, snapshot: SnapshotItem) {
        if let url = URL(string: asset.iconUrl) {
            assetImageView.sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"), options: [], completed: nil)
        }
        if let chainIconUrl = asset.chainIconUrl {
            blockchainImageView.sd_setImage(with: URL(string: chainIconUrl))
            blockchainImageView.isHidden = false
        } else {
            blockchainImageView.isHidden = true
        }

        switch snapshot.type {
        case SnapshotType.deposit.rawValue:
            amountLabel.textColor = .walletGreen
            amountLabel.text = "+\(snapshot.amount.formatBalance()) \(asset.symbol)"
        case SnapshotType.transfer.rawValue:
            let amount = snapshot.amount.toDouble()
            if amount > 0 {
                amountLabel.textColor = .walletGreen
                amountLabel.text = "+\(snapshot.amount.formatBalance()) \(asset.symbol)"
            } else {
                amountLabel.textColor = .walletRed
                amountLabel.text = "\(snapshot.amount.formatBalance()) \(asset.symbol)"
            }
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
            amountLabel.text = "\(snapshot.amount.formatBalance()) \(asset.symbol)"
        case SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
            amountLabel.text = "+\(snapshot.amount.formatBalance()) \(asset.symbol)"
        default:
            break
        }
        exchangeLabel.text = String(format: "≈ %@ USD", (snapshot.amount.toDouble() * asset.priceUsd.toDouble()).toFormatLegalTender())
    }

}
