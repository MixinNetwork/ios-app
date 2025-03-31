import Foundation

public final class LightningPaymentResponse: PaymentResponse {
    
    public struct Asset: Codable {
        
        public enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case chainID = "chain_id"
        }
        
        public let assetID: String
        public let chainID: String
        
    }
    
    private enum CodingKeys: String, CodingKey {
        case destination
        case amount
        case minimum
        case maximum
        case asset
    }
    
    public let destination: String
    public let amount: String
    public let minimum: String
    public let maximum: String
    public let asset: Asset
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.destination = try container.decode(String.self, forKey: .destination)
        self.amount = try container.decode(String.self, forKey: .amount)
        self.minimum = try container.decode(String.self, forKey: .minimum)
        self.maximum = try container.decode(String.self, forKey: .maximum)
        self.asset = try container.decode(Asset.self, forKey: .asset)
        try super.init(from: decoder)
    }
    
}
