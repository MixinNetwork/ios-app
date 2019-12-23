import Foundation

public struct Fee: Codable, NumberStringLocalizable {
    
    let type: String
    let assetId: String
    let amount: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case assetId = "asset_id"
        case amount
    }
    
    public var localizedAmount: String {
        return localizedNumberString(amount)
    }
    
}
