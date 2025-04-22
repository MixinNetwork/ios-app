import Foundation
import GRDB

open class Web3RawTransaction: Codable {
    
    public enum State: String, Codable {
        case notFound = "notfound"
        case pending
        case failed
        case success
    }
    
    public enum CodingKeys: String, CodingKey {
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
    public let state: UnknownableEnum<State>
    public let createdAt: String
    public let updatedAt: String
    
}

extension Web3RawTransaction: TableRecord, DatabaseColumnConvertible, PersistableRecord, MixinFetchableRecord, MixinEncodableRecord {
    
    public static let databaseTableName = "raw_transactions"
    
}
