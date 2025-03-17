import Foundation

public struct PaymentResponse: Codable {

    public let status: String
    public let destination: String?
    public let amount: String?
    public let minimum: String?
    public let maximum: String?
    public let asset: PaymentAsset?
    
}

public enum PaymentStatus: String, Codable {
    case pending
    case paid
}

// MARK: - Embedded structs
extension PaymentResponse {
    
    public struct PaymentAsset: Codable {
        
        public let assetId: String
        public let chainId: String
        
        public enum CodingKeys: String, CodingKey {
            case assetId = "asset_id"
            case chainId = "chain_id"
        }
    }
}
