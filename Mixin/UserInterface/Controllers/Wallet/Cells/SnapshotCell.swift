import UIKit

class SnapshotCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_snapshot"
    static let cellHeight: CGFloat = 60

    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    func render(snapshot: SnapshotItem, symbol: String) {
        timeLabel.text = DateFormatter.MMMddHHmm.string(from: snapshot.createdAt.toUTCDate())
        switch snapshot.type {
        case SnapshotType.deposit.rawValue:
            amountLabel.textColor = .deposit
            amountLabel.text = "+\(snapshot.amount.formatBalance()) \(symbol)"
            if let hash = snapshot.transactionHash {
                detailLabel.text = hash.toSimpleKey()
            } else {
                detailLabel.text = nil
            }
        case SnapshotType.transfer.rawValue:
            let amount = snapshot.amount.toDouble()
            if amount > 0 {
                amountLabel.textColor = .deposit
                detailLabel.text = Localized.WALLET_SNAPSHOT_FROM(fullName: snapshot.counterUserFullName ?? "")
                amountLabel.text = "+\(snapshot.amount.formatBalance()) \(symbol)"
            } else {
                amountLabel.textColor = .transfer
                detailLabel.text = Localized.WALLET_SNAPSHOT_TO(fullName: snapshot.counterUserFullName ?? "")
                amountLabel.text = "\(snapshot.amount.formatBalance()) \(symbol)"
            }
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue:
            amountLabel.textColor = .transfer
            amountLabel.text = "\(snapshot.amount.formatBalance()) \(symbol)"
            if let receiver = snapshot.receiver, !receiver.isEmpty {
                detailLabel.text = receiver.toSimpleKey()
            } else {
                detailLabel.text = nil
            }
        case SnapshotType.rebate.rawValue:
            amountLabel.textColor = .deposit
            amountLabel.text = "+\(snapshot.amount.formatBalance()) \(symbol)"
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
