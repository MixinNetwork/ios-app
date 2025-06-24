import Foundation

struct RouteProfile {
    
    let assetIDs: [String]
    let currencies: [String]
    
}

extension RouteProfile: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case assetIDs = "asset_ids"
        case currencies
    }
    
}
