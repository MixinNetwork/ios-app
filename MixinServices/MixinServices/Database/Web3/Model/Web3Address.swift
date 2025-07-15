import Foundation
import GRDB

public struct Web3Address {
    
    public let addressID: String
    public let walletID: String
    public let path: String
    public let chainID: String
    public let destination: String
    public let createdAt: String
    
    public init(
        addressID: String, walletID: String, path: String,
        chainID: String, destination: String, createdAt: String
    ) {
        self.addressID = addressID
        self.walletID = walletID
        self.path = path
        self.chainID = chainID
        self.destination = destination
        self.createdAt = createdAt
    }
    
}

extension Web3Address: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case addressID = "address_id"
        case walletID = "wallet_id"
        case path
        case chainID = "chain_id"
        case destination
        case createdAt = "created_at"
    }
    
}

extension Web3Address: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "addresses"
    
}
