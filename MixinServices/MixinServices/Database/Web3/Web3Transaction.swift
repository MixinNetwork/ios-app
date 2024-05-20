import Foundation
import GRDB

public struct Web3Transaction {
    
    let transactionHash: String
    let chainID: String
    let address: String
    let rawTransaction: String
    let nonce: Int
    let createdAt: String
    
    public init(
        transactionHash: String, chainID: String, address: String,
        rawTransaction: String, nonce: Int, createdAt: String
    ) {
        self.transactionHash = transactionHash
        self.chainID = chainID
        self.address = address
        self.rawTransaction = rawTransaction
        self.nonce = nonce
        self.createdAt = createdAt
    }
    
}

extension Web3Transaction: Encodable, DatabaseColumnConvertible, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case transactionHash = "transaction_hash"
        case chainID = "chain_id"
        case address
        case rawTransaction = "raw_transaction"
        case nonce
        case createdAt = "created_at"
    }
    
}

extension Web3Transaction: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "transactions"
    
}
