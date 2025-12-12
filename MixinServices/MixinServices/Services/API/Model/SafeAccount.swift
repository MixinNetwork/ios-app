import Foundation

public struct SafeAccount: Decodable {
    
    public enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case chainID = "chain_id"
        case name = "name"
        case address = "address"
        case role = "role"
        case assets = "assets"
        case uri = "uri"
        case createdAt = "created_at"
    }
    
    public let accountID: String
    public let chainID: Int
    public let name: String
    public let address: String
    public let role: String
    public let assets: [Asset]
    public let uri: String
    public let createdAt: String
    
}

extension SafeAccount {
    
    public struct Asset: Decodable {
        
        public enum CodingKeys: String, CodingKey {
            case mixinAssetID = "mixin_asset_id"
            case balance = "balance"
        }
        
        public let mixinAssetID: String
        public let balance: String
        
    }
    
    public enum Role: String, Codable {
        case owner = "owner"
        case member = "accountant"
    }
    
}

extension Web3Wallet {
    
    public convenience init?(account: SafeAccount) {
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
        self.init(
            walletID: account.accountID,
            category: .mixinSafe,
            name: account.name,
            createdAt: account.createdAt,
            updatedAt: Date().toUTCString(),
            safeRole: account.role,
            safeChainID: chainID,
            safeAddress: account.address,
            safeURL: account.uri
        )
    }
    
}
