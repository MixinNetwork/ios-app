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
        case SnapshotType.deposit.rawValue, SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
        case SnapshotType.transfer.rawValue:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
        default:
            break
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always, symbol: .custom(asset.symbol))
        let exchange = snapshot.amount.doubleValue * asset.priceUsd.doubleValue
        if let value = CurrencyFormatter.localizedString(from: exchange, format: .legalTender, sign: .never, symbol: .usd) {
            exchangeLabel.text = "≈ " + value
        } else {
            exchangeLabel.text = nil
        }
    }

}
