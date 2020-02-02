import Foundation

public struct Fee: Codable, NumberStringLocalizable {
    
    public let type: String
    public let assetId: String
    public let amount: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case assetId = "asset_id"
        case amount
    }
    
    public var localizedAmount: String {
        return localizedNumberString(amount)
    }
    
}
