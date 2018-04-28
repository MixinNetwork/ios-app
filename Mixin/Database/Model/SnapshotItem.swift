import WCDBSwift

struct SnapshotItem: TableCodable {

    let snapshotId: String
    let type: String
    let assetId: String
    let amount: String
    let transactionHash: String?
    let sender: String?
    let counterUserId: String?

    let createdAt: String
    let counterUserFullName: String?
    let receiver: String?

    let memo: String?

    enum CodingKeys: String, CodingTableKey {
        typealias Root = SnapshotItem
        case snapshotId = "snapshot_id"
        case type
        case assetId = "asset_id"
        case amount
        case counterUserId = "counter_user_id"
        case transactionHash = "transaction_hash"
        case sender
        case createdAt = "created_at"
        case counterUserFullName
        case receiver
        case memo

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
    }
}
