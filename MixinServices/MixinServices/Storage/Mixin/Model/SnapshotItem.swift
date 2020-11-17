import WCDBSwift

public class SnapshotItem: TableCodable {
    
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
    
    public private(set) lazy var decimalAmount = Decimal(string: amount) ?? 0
    
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

    public init(snapshot: Snapshot) {
        self.snapshotId = snapshot.snapshotId
        self.type = snapshot.type
        self.assetId = snapshot.assetId
        self.amount = snapshot.amount
        self.transactionHash = snapshot.transactionHash
        self.sender = snapshot.sender
        self.opponentId = snapshot.opponentId
        self.memo = snapshot.memo
        self.receiver = snapshot.receiver
        self.confirmations = snapshot.confirmations
        self.traceId = snapshot.traceId
        self.createdAt = snapshot.createdAt

        self.assetSymbol = nil
        self.opponentUserId = nil
        self.opponentUserFullName = nil
        self.opponentUserAvatarUrl = nil
        self.opponentUserIdentityNumber = nil
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
