import Foundation

public struct AddressFeeResponse: Codable {
    
    public let destination: String
    public let tag: String?
    public let fee: String
    public let feeAssetId: String
    
    enum CodingKeys: String, CodingKey {
        case destination
        case tag
        case fee
        case feeAssetId = "fee_asset_id"
    }
    
}
