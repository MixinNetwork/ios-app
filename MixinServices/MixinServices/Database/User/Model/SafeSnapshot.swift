import Foundation
import GRDB

public class SafeSnapshot: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
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
        case inscriptionHash = "inscription_hash"
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
    public let inscriptionHash: String?
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
    
    public var isInscription: Bool {
        !(inscriptionHash?.isEmpty ?? true)
    }
    
    public var displayTypes: Set<DisplayType> {
        if deposit != nil {
            if type == SnapshotType.pending.rawValue {
                [.deposit, .pending]
            } else {
                [.deposit]
            }
        } else if withdrawal != nil {
            [.withdrawal]
        } else {
            [.transfer]
        }
    }
    
    public init(
        id: String, type: String, assetID: String, amount: String,
        userID: String, opponentID: String, memo: String,
        transactionHash: String, createdAt: String,
        traceID: String?, confirmations: Int?,
        openingBalance: String?, closingBalance: String?, 
        inscriptionHash: String?, deposit: Deposit?,
        withdrawal: Withdrawal?
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
        self.inscriptionHash = inscriptionHash
        self.deposit = deposit
        self.withdrawal = withdrawal
    }
    
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
        self.inscriptionHash = nil
        self.deposit = deposit
        self.withdrawal = withdrawal
    }
    
    public init(
        type: SnapshotType, assetID: String, amount: String,
        userID: String, opponentID: String, memo: String,
        transactionHash: String, createdAt: String,
        traceID: String, inscriptionHash: String?, 
        withdrawal: Withdrawal? = nil
    ) {
        self.id = "\(userID):\(transactionHash)".uuidDigest()
        self.type = type.rawValue
        self.assetID = assetID
        self.amount = amount
        self.userID = userID
        self.opponentID = opponentID
        self.memo = memo
        self.transactionHash = transactionHash
        self.createdAt = createdAt
        self.traceID = traceID
        self.confirmations = nil
        self.openingBalance = nil
        self.closingBalance = nil
        self.inscriptionHash = inscriptionHash
        self.deposit = nil
        self.withdrawal = withdrawal
    }
    
    func replacing(deposit: Deposit) -> SafeSnapshot {
        SafeSnapshot(
            id: self.id,
            type: self.type,
            assetID: self.assetID,
            amount: self.amount,
            userID: self.userID,
            opponentID: self.opponentID,
            memo: self.memo,
            transactionHash: self.transactionHash,
            createdAt: self.createdAt,
            traceID: self.traceID,
            confirmations: self.confirmations,
            openingBalance: self.openingBalance,
            closingBalance: self.closingBalance,
            inscriptionHash: self.inscriptionHash,
            deposit: deposit,
            withdrawal: self.withdrawal
        )
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
        
        public init(hash: String, receiver: String) {
            self.hash = hash
            self.receiver = receiver
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.hash = try container.decode(String.self, forKey: .hash)
            self.receiver = try container.decodeIfPresent(String.self, forKey: .receiver) ?? ""
        }
        
    }
    
}

extension SafeSnapshot {
    
    public enum DisplayType {
        case deposit
        case withdrawal
        case transfer
        case pending
    }
    
    public enum SnapshotType: String {
        case snapshot // Only value that returns from remote
        case pending // Local only
        case withdrawal // Local only
    }
    
    public enum Order {
        case newest
        case oldest
        case mostValuable
        case biggestAmount
    }
    
    public struct Filter: CustomStringConvertible {
        
        // For array-type properties, when the value is empty,
        // it indicates that this filter should not be applied.
        
        public var type: SafeSnapshot.DisplayType?
        public var tokens: [MixinTokenItem]
        public var users: [UserItem]
        public var addresses: [AddressItem]
        public var startDate: Date?
        public var endDate: Date?
        
        public var description: String {
            "<Filter type: \(type), tokens: \(tokens.map(\.symbol)), users: \(users.map(\.fullName)), addresses: \(addresses.map(\.label)), startDate: \(startDate), endDate: \(endDate)>"
        }
        
        public init(
            type: SafeSnapshot.DisplayType? = nil,
            tokens: [MixinTokenItem] = [],
            users: [UserItem] = [],
            addresses: [AddressItem] = [],
            startDate: Date? = nil,
            endDate: Date? = nil
        ) {
            self.type = type
            self.tokens = tokens
            self.users = users
            self.addresses = addresses
            self.startDate = startDate
            self.endDate = endDate
        }
        
        public func isIncluded(snapshot: SafeSnapshot) -> Bool {
            var isIncluded = true
            if let type {
                isIncluded = isIncluded && snapshot.displayTypes.contains(type)
            }
            if !tokens.isEmpty {
                isIncluded = isIncluded && tokens.contains(where: { $0.assetID == snapshot.assetID })
            }
            if !users.isEmpty {
                isIncluded = isIncluded && users.contains(where: { $0.userId == snapshot.opponentID })
            }
            if !addresses.isEmpty {
                isIncluded = isIncluded && addresses.contains(where: { address in
                    snapshot.deposit?.sender == address.destination || snapshot.withdrawal?.receiver == address.destination
                })
            }
            if let startDate {
                isIncluded = isIncluded && snapshot.createdAt.toUTCDate() >= startDate
            }
            if let endDate {
                isIncluded = isIncluded && snapshot.createdAt.toUTCDate() <= endDate
            }
            return isIncluded
        }
        
    }
    
}
