import UIKit

class SnapshotCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_snapshot"
    static let cellHeight: CGFloat = 60

    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    func render(snapshot: SnapshotItem) {
        timeLabel.text = DateFormatter.MMMddHHmm.string(from: snapshot.createdAt.toUTCDate())
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always, symbol: .custom(snapshot.assetSymbol))
        switch snapshot.type {
        case SnapshotType.deposit.rawValue:
            amountLabel.textColor = .walletGreen
            if let hash = snapshot.transactionHash {
                detailLabel.text = hash.toSimpleKey()
            } else {
                detailLabel.text = nil
            }
        case SnapshotType.transfer.rawValue:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
                detailLabel.text = Localized.WALLET_SNAPSHOT_TO(fullName: snapshot.opponentUserFullName ?? "")
            } else {
                amountLabel.textColor = .walletGreen
                detailLabel.text = Localized.WALLET_SNAPSHOT_FROM(fullName: snapshot.opponentUserFullName ?? "")
            }
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
            if let receiver = snapshot.receiver, !receiver.isEmpty {
                detailLabel.text = receiver.toSimpleKey()
            } else {
                detailLabel.text = nil
            }
        case SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
            if let receiver = snapshot.receiver, !receiver.isEmpty {
                detailLabel.text = receiver.toSimpleKey()
            } else {
                detailLabel.text = nil
            }
        default:
            break
        }
    }

}
