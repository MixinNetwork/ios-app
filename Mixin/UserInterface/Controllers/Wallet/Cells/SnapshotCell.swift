import UIKit

class SnapshotCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_snapshot"
    static let cellHeight: CGFloat = 60

    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    func render(snapshot: SnapshotItem) {
        let symbol = snapshot.assetSymbol
        timeLabel.text = DateFormatter.MMMddHHmm.string(from: snapshot.createdAt.toUTCDate())
        switch snapshot.type {
        case SnapshotType.deposit.rawValue:
            amountLabel.textColor = .walletGreen
            amountLabel.text = "+\(snapshot.amount.formatFullBalance()) \(symbol)"
            if let hash = snapshot.transactionHash {
                detailLabel.text = hash.toSimpleKey()
            } else {
                detailLabel.text = nil
            }
        case SnapshotType.transfer.rawValue:
            let amount = snapshot.amount.toDouble()
            if amount > 0 {
                amountLabel.textColor = .walletGreen
                detailLabel.text = Localized.WALLET_SNAPSHOT_FROM(fullName: snapshot.opponentUserFullName ?? "")
                amountLabel.text = "+\(snapshot.amount.formatFullBalance()) \(symbol)"
            } else {
                amountLabel.textColor = .walletRed
                detailLabel.text = Localized.WALLET_SNAPSHOT_TO(fullName: snapshot.opponentUserFullName ?? "")
                amountLabel.text = "\(snapshot.amount.formatFullBalance()) \(symbol)"
            }
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
            amountLabel.text = "\(snapshot.amount.formatFullBalance()) \(symbol)"
            if let receiver = snapshot.receiver, !receiver.isEmpty {
                detailLabel.text = receiver.toSimpleKey()
            } else {
                detailLabel.text = nil
            }
        case SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
            amountLabel.text = "+\(snapshot.amount.formatFullBalance()) \(symbol)"
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
