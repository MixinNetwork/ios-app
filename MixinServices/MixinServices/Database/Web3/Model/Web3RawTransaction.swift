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
    
    public init(
        hash: String, chainID: String, account: String,
        nonce: String, raw: String,
        state: UnknownableEnum<Web3RawTransaction.State>,
        createdAt: String, updatedAt: String
    ) {
        self.hash = hash
        self.chainID = chainID
        self.account = account
        self.nonce = nonce
        self.raw = raw
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
}

extension Web3RawTransaction: TableRecord, DatabaseColumnConvertible, PersistableRecord, MixinFetchableRecord, MixinEncodableRecord {
    
    public static let databaseTableName = "raw_transactions"
    
}
