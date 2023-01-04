import Foundation

public struct AssetPrecisionResponse: Codable {

    public let assetId: String
    public let chainId: String
    public let precision: Int
    
    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case chainId = "chain_id"
        case precision
    }
    
}
