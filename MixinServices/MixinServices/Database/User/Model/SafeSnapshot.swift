import Foundation
import GRDB

public class SafeSnapshot: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum SnapshotType: String, CaseIterable {
        case snapshot
        case pending
    }
    
    public enum CodingKeys: String, CodingKey {
        case id = "snapshot_id"
        case type
        case assetID = "asset_id"
        case amount
        case userID = "user_id"
        case opponentID = "opponent_id"
        case memo
        case transactionHash = "transaction_hash"
        case createdAt = "created_at"
        case traceID = "trace_id"
        case confirmations
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
    }
    
    public let id: String
    public let type: String
    public let assetID: String
    public let amount: String
    public let userID: String
    public let opponentID: String
    public let memo: String
    public let transactionHash: String
    public let createdAt: String
    public let traceID: String?
    public let confirmations: Int?
    public let openingBalance: String?
    public let closingBalance: String?
    
    public private(set) lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
    
    public init(
        id: String, type: String, assetID: String, amount: String,
        userID: String, opponentID: String, memo: String,
        transactionHash: String, createdAt: String,
        traceID: String?, confirmations: Int?,
        openingBalance: String?, closingBalance: String?
    ) {
        self.id = id
        self.type = type
        self.assetID = assetID
        self.amount = amount
        self.userID = userID
        self.opponentID = opponentID
        self.memo = memo
        self.transactionHash = transactionHash
        self.createdAt = createdAt
        self.traceID = traceID
        self.confirmations = confirmations
        self.openingBalance = openingBalance
        self.closingBalance = closingBalance
    }
    
    public init(assetID: String, pendingDeposit: SafePendingDeposit) {
        self.id = pendingDeposit.id
        self.type = SnapshotType.pending.rawValue
        self.assetID = assetID
        self.amount = pendingDeposit.amount
        self.userID = myUserId
        self.opponentID = ""
        self.transactionHash = pendingDeposit.transactionHash
        self.memo = ""
        self.createdAt = pendingDeposit.createdAt
        self.traceID = ""
        self.confirmations = pendingDeposit.confirmations
        self.openingBalance = nil
        self.closingBalance = nil
    }
    
}

extension SafeSnapshot: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "safe_snapshots"
    
}
