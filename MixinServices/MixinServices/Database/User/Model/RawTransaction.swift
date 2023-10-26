import Foundation
import GRDB

public struct RawTransaction {
    
    public let requestID: String
    public let rawTransaction: String
    public let receiverID: String
    public let createdAt: Date
    
    public init(requestID: String, rawTransaction: String, receiverID: String, createdAt: Date) {
        self.requestID = requestID
        self.rawTransaction = rawTransaction
        self.receiverID = receiverID
        self.createdAt = createdAt
    }
    
}

extension RawTransaction: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case rawTransaction = "raw_transaction"
        case receiverID = "receiver_id"
        case createdAt = "created_at"
    }
    
}

extension RawTransaction: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "raw_transactions"
    
}
