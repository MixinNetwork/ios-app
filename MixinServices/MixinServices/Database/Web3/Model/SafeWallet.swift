import Foundation
import GRDB

public struct SafeWallet: Codable {
    
    public enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case name = "name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case role = "role"
        case chainID = "chain_id"
        case address = "address"
        case uri = "uri"
    }
    
    public let walletID: String
    public let name: String
    public let createdAt: String
    public let updatedAt: String
    public let role: UnknownableEnum<SafeAccount.Role>
    public let chainID: String
    public let address: String
    public let uri: String
    
    public init?(account: SafeAccount) {
        let chainID: String
        switch account.chainID {
        case 1:
            chainID = ChainID.bitcoin
        case 2:
            chainID = ChainID.ethereum
        case 5:
            chainID = ChainID.litecoin
        case 6:
            chainID = ChainID.polygon
        default:
            return nil
        }
        
        self.walletID = account.accountID
        self.name = account.name
        self.createdAt = account.createdAt
        self.updatedAt = Date().toUTCString()
        self.role = .init(rawValue: account.role)
        self.chainID = chainID
        self.address = account.address
        self.uri = account.uri
    }
    
}

extension SafeWallet: MixinFetchableRecord, PersistableRecord, DatabaseColumnConvertible {
    
    public static let databaseTableName = "safe_wallets"
    
}
