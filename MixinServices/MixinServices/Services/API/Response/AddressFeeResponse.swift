import Foundation

public struct AddressFeeResponse: Codable {

    public let destination: String
    public let assetId: String
    public let fee: String
    public let tag: String?
    
    enum CodingKeys: String, CodingKey {
        case destination
        case assetId = "fee_asset_id"
        case fee
        case tag
    }
    
}
