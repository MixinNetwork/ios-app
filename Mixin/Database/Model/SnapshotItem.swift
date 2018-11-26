import WCDBSwift

struct SnapshotItem: TableCodable {

    let snapshotId: String
    let type: String
    let assetId: String
    let assetSymbol: String?
    let amount: String
    let transactionHash: String?
    let sender: String?
    let opponentId: String?

    let createdAt: String
    let receiver: String?
    let confirmations: Int?

    let memo: String?
    
    let opponentUserId: String?
    let opponentUserFullName: String?
    let opponentUserAvatarUrl: String?
    let opponentUserIdentityNumber: String?
    
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
        case receiver
        case confirmations
        case memo
        case opponentUserId = "opponent_user_id"
        case opponentUserFullName = "opponent_user_full_name"
        case opponentUserAvatarUrl = "opponent_user_avatar_url"
        case opponentUserIdentityNumber = "opponent_user_identity_number"
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
    }
}
