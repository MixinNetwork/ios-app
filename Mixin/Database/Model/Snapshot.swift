import Foundation
import WCDBSwift

struct Snapshot: BaseCodable {

    static var tableName: String = "snapshots"

    let snapshotId: String
    let type: String
    let assetId: String
    let amount: String
    let transactionHash: String?
    let sender: String?
    let opponentId: String?
    let memo: String?
    let receiver: String?
    var createdAt: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Snapshot
        case snapshotId = "snapshot_id"
        case type
        case assetId = "asset_id"
        case amount
        case opponentId = "opponent_id"
        case transactionHash = "transaction_hash"
        case sender
        case receiver
        case memo
        case createdAt = "created_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                snapshotId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
}

enum SnapshotType: String {
    case deposit
    case transfer
    case withdrawal
    case fee
    case rebate
}
