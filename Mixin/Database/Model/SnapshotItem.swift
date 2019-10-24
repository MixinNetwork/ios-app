import WCDBSwift

struct SnapshotItem: TableDecodable {

    let snapshotId: String
    let type: String
    let assetId: String
    let amount: String
    let opponentId: String?
    let transactionHash: String?
    let sender: String?
    let receiver: String?
    let memo: String?
    let confirmations: Int?
    let createdAt: String
    
    let assetSymbol: String?
    
    let opponentUserId: String?
    let opponentUserFullName: String?
    let opponentUserAvatarUrl: String?
    let opponentUserIdentityNumber: String?
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = SnapshotItem
        case snapshotId = "snapshot_id"
        case type
        case assetId = "asset_id"
        case amount
        case opponentId = "opponent_id"
        case transactionHash = "transaction_hash"
        case sender
        case receiver
        case memo
        case confirmations
        case createdAt = "created_at"
        
        case assetSymbol = "symbol"
        
        case opponentUserId = "user_id"
        case opponentUserFullName = "full_name"
        case opponentUserAvatarUrl = "avatar_url"
        case opponentUserIdentityNumber = "identity_number"
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
    }
    
}

extension SnapshotItem {

    var hasSender: Bool {
        return !(sender?.isEmpty ?? true)
    }

    var hasReceiver: Bool {
        return !(receiver?.isEmpty ?? true)
    }

    var hasMemo: Bool {
        return !(memo?.isEmpty ?? true)
    }

}
