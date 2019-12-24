import WCDBSwift

public struct SnapshotItem: TableCodable {
    
    public let snapshotId: String
    public let type: String
    public let assetId: String
    public let amount: String
    public let opponentId: String?
    public let transactionHash: String?
    public let sender: String?
    public let receiver: String?
    public let memo: String?
    public let confirmations: Int?
    public let traceId: String?
    public let createdAt: String
    
    public let assetSymbol: String?
    
    public let opponentUserId: String?
    public let opponentUserFullName: String?
    public let opponentUserAvatarUrl: String?
    public let opponentUserIdentityNumber: String?
    
    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = SnapshotItem
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
        case traceId = "trace_id"
        case createdAt = "created_at"
        
        case assetSymbol = "symbol"
        
        case opponentUserId = "user_id"
        case opponentUserFullName = "full_name"
        case opponentUserAvatarUrl = "avatar_url"
        case opponentUserIdentityNumber = "identity_number"
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
    }
    
}

extension SnapshotItem {
    
    public var hasSender: Bool {
        return !(sender?.isEmpty ?? true)
    }
    
    public var hasReceiver: Bool {
        return !(receiver?.isEmpty ?? true)
    }
    
    public var hasMemo: Bool {
        return !(memo?.isEmpty ?? true)
    }
    
}
