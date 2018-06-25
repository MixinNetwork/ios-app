import WCDBSwift

struct SnapshotItem: TableCodable {

    let snapshotId: String
    let type: String
    let assetId: String
    let assetSymbol: String
    let amount: String
    let transactionHash: String?
    let sender: String?
    let opponentId: String?

    let createdAt: String
    let opponentUserFullName: String?
    let receiver: String?

    let memo: String?

    enum CodingKeys: String, CodingTableKey {
        typealias Root = SnapshotItem
        case snapshotId = "snapshot_id"
        case type
        case assetId = "asset_id"
        case assetSymbol
        case amount
        case opponentId = "opponent_id"
        case transactionHash = "transaction_hash"
        case sender
        case createdAt = "created_at"
        case opponentUserFullName
        case receiver
        case memo

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
    }
}
