import Foundation
import GRDB

public class SafeSnapshot: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum SnapshotType: String {
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
        case deposit
        case withdrawal
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
    public let deposit: Deposit?
    public let withdrawal: Withdrawal?
    
    public private(set) lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var utf8DecodedMemo: String? = {
        if let data = Data(hexEncodedString: memo) {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }()
    
    public init(
        id: String, type: SnapshotType, assetID: String, amount: String,
        userID: String, opponentID: String, memo: String,
        transactionHash: String, createdAt: String,
        traceID: String?, confirmations: Int?,
        openingBalance: String?, closingBalance: String?,
        deposit: Deposit?, withdrawal: Withdrawal?
    ) {
        self.id = id
        self.type = type.rawValue
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
        self.deposit = deposit
        self.withdrawal = withdrawal
    }
    
    public init(assetID: String, pendingDeposit: SafePendingDeposit) {
        self.id = pendingDeposit.id
        self.type = SnapshotType.pending.rawValue
        self.assetID = assetID
        self.amount = pendingDeposit.amount
        self.userID = myUserId
        self.opponentID = ""
        self.transactionHash = ""
        self.memo = ""
        self.createdAt = pendingDeposit.createdAt
        self.traceID = ""
        self.confirmations = pendingDeposit.confirmations
        self.openingBalance = nil
        self.closingBalance = nil
        self.deposit = Deposit(hash: pendingDeposit.transactionHash, sender: "")
        self.withdrawal = nil
    }
    
}

extension SafeSnapshot: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "safe_snapshots"
    
}

extension SafeSnapshot {
    
    public final class Deposit: Codable {
        
        public enum CodingKeys: String, CodingKey {
            case hash = "deposit_hash"
            case sender
        }
        
        public let hash: String
        public let sender: String
        
        public private(set) lazy var compactSender = Address.compactRepresentation(of: sender)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.hash = try container.decode(String.self, forKey: .hash)
            self.sender = try container.decodeIfPresent(String.self, forKey: .sender) ?? ""
        }
        
        public init(hash: String, sender: String) {
            self.hash = hash
            self.sender = sender
        }
        
    }
    
    public final class Withdrawal: Codable {
        
        public enum CodingKeys: String, CodingKey {
            case hash = "withdrawal_hash"
            case receiver
        }
        
        public let hash: String
        public let receiver: String
        
        public private(set) lazy var compactReceiver = Address.compactRepresentation(of: receiver)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.hash = try container.decode(String.self, forKey: .hash)
            self.receiver = try container.decodeIfPresent(String.self, forKey: .receiver) ?? ""
        }
        
    }
    
}
