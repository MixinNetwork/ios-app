import UIKit

class PeerTransactionSnapshotCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_snapshot"
    static let cellHeight: CGFloat = 60

    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var pendingLabel: UILabel!
    
    func render(snapshot: SnapshotItem, asset: AssetItem? = nil) {
        timeLabel.text = DateFormatter.MMMddHHmm.string(from: snapshot.createdAt.toUTCDate())
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always, symbol: .custom(snapshot.assetSymbol ?? ""))
        pendingLabel.isHidden = snapshot.type != SnapshotType.pendingDeposit.rawValue
        switch snapshot.type {
        case SnapshotType.deposit.rawValue:
            amountLabel.textColor = .walletGreen
            detailLabel.text = Localized.TRANSACTION_TYPE_DEPOSIT
        case SnapshotType.transfer.rawValue:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
                detailLabel.text = Localized.WALLET_SNAPSHOT_TO(fullName: snapshot.opponentUserFullName ?? "")
            } else {
                amountLabel.textColor = .walletGreen
                detailLabel.text = Localized.WALLET_SNAPSHOT_FROM(fullName: snapshot.opponentUserFullName ?? "")
            }
        case SnapshotType.withdrawal.rawValue:
            amountLabel.textColor = .walletRed
            detailLabel.text = Localized.TRANSACTION_TYPE_WITHDRAWAL
        case SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
            detailLabel.text = Localized.TRANSACTION_TYPE_FEE
        case SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
            detailLabel.text = Localized.TRANSACTION_TYPE_REBATE
        case SnapshotType.pendingDeposit.rawValue:
            amountLabel.textColor = .walletGray
            if let confirmations = snapshot.confirmations {
                detailLabel.text = Localized.PENDING_DEPOSIT_CONFIRMATION(numerator: confirmations, denominator: asset?.confirmations)
            } else {
                detailLabel.text = nil
            }
        default:
            break
        }
    }

}
