import Foundation
import GRDB

public class Web3Wallet: Codable {
    
    public enum Category: String, Codable {
        case classic
        case importedMnemonic = "imported_mnemonic"
        case importedPrivateKey = "imported_private_key"
        case watchAddress = "watch_address"
    }
    
    public enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case category = "category"
        case name = "name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public let walletID: String
    public let category: UnknownableEnum<Web3Wallet.Category>
    public let name: String
    public let createdAt: String
    public let updatedAt: String
    
}

extension Web3Wallet: MixinFetchableRecord, PersistableRecord, DatabaseColumnConvertible {
    
    public static let databaseTableName = "wallets"
    
}

extension Web3Wallet: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "<Web3Wallet id: \(walletID), category: \(category.rawValue), name: \(name)>"
    }
    
}
