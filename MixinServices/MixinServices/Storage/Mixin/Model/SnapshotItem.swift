import Foundation
import GRDB

public struct SnapshotItem {
    
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

extension SnapshotItem: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
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
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snapshotId = try container.decode(String.self, forKey: .snapshotId)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        assetId = try container.decodeIfPresent(String.self, forKey: .assetId) ?? ""
        amount = try container.decodeIfPresent(String.self, forKey: .amount) ?? ""
        opponentId = try container.decodeIfPresent(String.self, forKey: .opponentId)
        transactionHash = try container.decodeIfPresent(String.self, forKey: .transactionHash)
        sender = try container.decodeIfPresent(String.self, forKey: .sender)
        receiver = try container.decodeIfPresent(String.self, forKey: .receiver)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
        confirmations = try container.decodeIfPresent(Int.self, forKey: .confirmations)
        traceId = try container.decodeIfPresent(String.self, forKey: .traceId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        
        assetSymbol = try container.decodeIfPresent(String.self, forKey: .assetSymbol)
        
        opponentUserId = try container.decodeIfPresent(String.self, forKey: .opponentUserId)
        opponentUserFullName = try container.decodeIfPresent(String.self, forKey: .opponentUserFullName)
        opponentUserAvatarUrl = try container.decodeIfPresent(String.self, forKey: .opponentUserAvatarUrl)
        opponentUserIdentityNumber = try container.decodeIfPresent(String.self, forKey: .opponentUserIdentityNumber)
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
