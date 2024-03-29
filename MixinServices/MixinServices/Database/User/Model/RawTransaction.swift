import Foundation
import GRDB

public struct RawTransaction {
    
    public enum State: String {
        case unspent
        case signed
    }
    
    public enum TransactionType: Int {
        case transfer = 0
        case withdrawal = 1
        case fee = 2
    }
    
    public let requestID: String
    public let rawTransaction: String
    public let receiverID: String
    public let state: String
    public let type: Int
    public let createdAt: String
    
    public init(
        requestID: String,
        rawTransaction: String,
        receiverID: String,
        state: State,
        type: TransactionType,
        createdAt: String
    ) {
        self.requestID = requestID
        self.rawTransaction = rawTransaction
        self.receiverID = receiverID
        self.state = state.rawValue
        self.type = type.rawValue
        self.createdAt = createdAt
    }
    
}

extension RawTransaction: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case rawTransaction = "raw_transaction"
        case receiverID = "receiver_id"
        case state
        case type
        case createdAt = "created_at"
    }
    
}

extension RawTransaction: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "raw_transactions"
    
}
