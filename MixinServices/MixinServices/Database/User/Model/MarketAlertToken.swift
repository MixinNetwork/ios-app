import Foundation
import GRDB

public struct MarketAlertToken {
    
    public let assetID: String
    public let name: String
    public let iconURL: String
    public let usdPrice: String
    
}

extension MarketAlertToken: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case name
        case iconURL = "icon_url"
        case usdPrice = "price_usd"
    }
    
}
