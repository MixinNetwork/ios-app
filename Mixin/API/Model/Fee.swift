import Foundation

struct Fee: Codable {
    let type: String
    let assetId: String
    let amount: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case assetId = "asset_id"
        case amount
    }
    
    var localizedAmount: String {
        return decimalSeparatorLocalized(amount)
    }
}
