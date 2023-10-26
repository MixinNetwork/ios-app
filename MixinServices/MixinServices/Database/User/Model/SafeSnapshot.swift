import Foundation
import GRDB

public class SafeSnapshot: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum SnapshotType: String, CaseIterable {
        case snapshot
    }
    
    public enum CodingKeys: String, CodingKey {
        case id = "snapshot_id"
        case type
        case assetID = "asset_id"
        case amount
        case opponentID = "opponent_id"
        case transactionHash = "transaction_hash"
        case memo
        case createdAt = "created_at"
        case traceID = "trace_id"
        case sender
        case receiver
        case confirmations
        case snapshotHash = "snapshot_hash"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
    }
    
    public let id: String
    public let type: String
    public let assetID: String
    public let amount: String
    public let opponentID: String
    public let transactionHash: String
    public let memo: String
    public let createdAt: Date
    public let traceID: String?
    public let sender: String?
    public let receiver: String?
    public let confirmations: Int?
    public let snapshotHash: String?
    public let openingBalance: String?
    public let closingBalance: String?
    
    public init(
        id: String, type: String, assetID: String, amount: String, opponentID: String,
        transactionHash: String, memo: String, createdAt: Date, traceID: String?,
        sender: String?, receiver: String?, confirmations: Int?, snapshotHash: String?,
        openingBalance: String?, closingBalance: String?
    ) {
        self.id = id
        self.type = type
        self.assetID = assetID
        self.amount = amount
        self.opponentID = opponentID
        self.transactionHash = transactionHash
        self.memo = memo
        self.createdAt = createdAt
        self.traceID = traceID
        self.sender = sender
        self.receiver = receiver
        self.confirmations = confirmations
        self.snapshotHash = snapshotHash
        self.openingBalance = openingBalance
        self.closingBalance = closingBalance
    }
    
}

extension SafeSnapshot: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "safe_snapshots"
    
}
