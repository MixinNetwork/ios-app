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
            case usdPrice = "price_usd"
        }
        
        public let mixinAssetID: String
        public let balance: String
        public let usdPrice: String
        
    }
    
}
