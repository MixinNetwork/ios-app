import Foundation

public struct SafeAccount: Decodable {
    
    public enum CodingKeys: String, CodingKey {
        case type = "type"
        case operationID = "operation_id"
        case accountID = "account_id"
        case chainID = "chain_id"
        case userID = "user_id"
        case name = "name"
        case datumPublic = "public"
        case owners = "owners"
        case assetID = "asset_id"
        case threshold = "threshold"
        case address = "address"
        case status = "status"
        case role = "role"
        case accountType = "account_type"
        case keys = "keys"
        case script = "script"
        case hmac = "hmac"
        case timelock = "timelock"
        case lockStatus = "lock_status"
        case latestUtxo = "latest_utxo"
        case assets = "assets"
        case uri = "uri"
        case createdAt = "created_at"
    }
    
    public let type: String
    public let operationID: String
    public let accountID: String
    public let chainID: Int
    public let userID: String
    public let name: String
    public let datumPublic: String
    public let owners: [String]
    public let assetID: String
    public let threshold: Int
    public let address: String
    public let status: String
    public let role: String
    public let accountType: String
    public let keys: [String]
    public let script: String
    public let hmac: String
    public let timelock: Int
    public let lockStatus: String
    public let latestUtxo: String
    public let assets: [Asset]
    public let uri: String
    public let createdAt: String
    
}

extension SafeAccount {
    
    public struct Asset: Decodable {
        
        public enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case mixinAssetID = "mixin_asset_id"
            case accountID = "account_id"
            case address = "address"
            case name = "name"
            case symbol = "symbol"
            case decimal = "decimal"
            case balance = "balance"
            case priceUsd = "price_usd"
            case iconURL = "icon_url"
            case recoverAmount = "recover_amount"
        }
        
        public let assetID: String
        public let mixinAssetID: String
        public let accountID: String
        public let address: String
        public let name: String
        public let symbol: String
        public let decimal: Int
        public let balance: String
        public let priceUsd: String
        public let iconURL: String
        public let recoverAmount: String
        
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
