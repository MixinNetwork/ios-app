import Foundation
import GRDB

public struct Web3Wallet {
    
    public enum Category: String, Codable {
        case classic
    }
    
    public let walletID: String
    public let category: String
    public let name: String
    public let createdAt: String
    
}

extension Web3Wallet: Codable {
    
    public enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case category = "category"
        case name = "name"
        case createdAt = "created_at"
    }
    
}

extension Web3Wallet: PersistableRecord, DatabaseColumnConvertible {
    
    public static let databaseTableName = "wallets"
    
}
