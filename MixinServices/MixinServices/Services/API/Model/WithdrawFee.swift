import Foundation

public struct WithdrawFee {
    
    public let amount: String
    public let assetID: String
    public let type: String
    
}

extension WithdrawFee: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case amount
        case assetID = "asset_id"
        case type
    }
    
}
