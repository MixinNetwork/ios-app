import Foundation
import GRDB

public struct Web3RawTransaction: Codable {
    
    enum CodingKeys: String, CodingKey {
        case hash = "hash"
        case chainID = "chain_id"
        case account = "account"
        case nonce = "nonce"
        case raw = "raw"
        case state = "state"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public let hash: String
    public let chainID: String
    public let account: String
    public let nonce: String
    public let raw: String
    public let state: String
    public let createdAt: String
    public let updatedAt: String
    
}

extension Web3RawTransaction: TableRecord, PersistableRecord, MixinFetchableRecord, MixinEncodableRecord {
    
    public static let databaseTableName = "raw_transactions"
    
}
