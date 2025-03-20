import Foundation
import GRDB

public struct Web3Address {
    
    public let addressID: String
    public let walletID: String
    public let chainID: String
    public let destination: String
    public let createdAt: String
    
    public init(
        addressID: String, walletID: String, chainID: String,
        destination: String, createdAt: String
    ) {
        self.addressID = addressID
        self.walletID = walletID
        self.chainID = chainID
        self.destination = destination
        self.createdAt = createdAt
    }
    
}

extension Web3Address: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case addressID = "address_id"
        case walletID = "wallet_id"
        case chainID = "chain_id"
        case destination
        case createdAt = "created_at"
    }
    
}

extension Web3Address: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "addresses"
    
}
