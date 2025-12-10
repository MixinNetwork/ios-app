import Foundation
import GRDB

public class Web3Wallet: Codable {
    
    public enum Category: String, Codable {
        case classic
        case importedMnemonic = "imported_mnemonic"
        case importedPrivateKey = "imported_private_key"
        case watchAddress = "watch_address"
        case mixinSafe = "mixin_safe"
    }
    
    public enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case category = "category"
        case name = "name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case safeRole = "safe_role"
        case safeChainID = "safe_chain_id"
        case safeAddress = "safe_address"
        case safeURL = "safe_url"
    }
    
    public let walletID: String
    public let category: UnknownableEnum<Web3Wallet.Category>
    public let name: String
    public let createdAt: String
    public let updatedAt: String
    public let safeRole: UnknownableEnum<SafeAccount.Role>?
    public let safeChainID: String?
    public let safeAddress: String?
    public let safeURL: String?
    
    init(
        walletID: String, category: Category, name: String,
        createdAt: String, updatedAt: String, safeRole: String?,
        safeChainID: String?, safeAddress: String?, safeURL: String?
    ) {
        self.walletID = walletID
        self.category = .known(category)
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.safeRole = if let safeRole {
            .init(rawValue: safeRole)
        } else {
            nil
        }
        self.safeChainID = safeChainID
        self.safeAddress = safeAddress
        self.safeURL = safeURL
    }
    
}

extension Web3Wallet: MixinFetchableRecord, PersistableRecord, DatabaseColumnConvertible {
    
    public static let databaseTableName = "wallets"
    
}

extension Web3Wallet: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "<Web3Wallet id: \(walletID), category: \(category.rawValue), name: \(name)>"
    }
    
}
