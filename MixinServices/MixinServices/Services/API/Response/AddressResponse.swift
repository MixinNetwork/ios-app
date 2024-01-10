import Foundation

public struct AddressResponse: Codable {
    
    public let destination: String
    public let tag: String?
    public let feeAssetId: String
    
    enum CodingKeys: String, CodingKey {
        case destination
        case tag
        case feeAssetId = "fee_asset_id"
    }
    
}
