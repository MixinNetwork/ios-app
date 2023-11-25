import Foundation
import GRDB

public struct AppToken {
    
    public let assetID: String
    public let balance: String
    public let chainID: String
    public let symbol: String
    public let name: String
    public let iconURL: String
    
}

extension AppToken: Codable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case balance
        case chainID = "chain_id"
        case symbol
        case name
        case iconURL = "icon_url"
    }
    
}
