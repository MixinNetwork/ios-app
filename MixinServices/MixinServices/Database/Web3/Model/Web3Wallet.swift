import Foundation
import GRDB

public class Web3Wallet: Codable {
    
    public enum Category: String, Codable {
        case classic
    }
    
    public enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case category = "category"
        case name = "name"
        case createdAt = "created_at"
    }
    
    public let walletID: String
    public let category: String
    public let name: String
    public let createdAt: String
    
}

extension Web3Wallet: MixinFetchableRecord, PersistableRecord, DatabaseColumnConvertible {
    
    public static let databaseTableName = "wallets"
    
}
