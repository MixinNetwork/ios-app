import UIKit

public final class PerpetualPositionHistoryItem: PerpetualPositionHistory {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case symbol = "symbol"
        case product = "product"
        case iconURL = "icon_url"
    }
    
    public let symbol: String
    public let product: String?
    public let iconURL: URL?
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        let symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        let product = try container.decodeIfPresent(String.self, forKey: .product)
        let iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
        
        self.symbol = symbol ?? "⍰"
        self.product = product
        self.iconURL = if let iconURL {
            URL(string: iconURL)
        } else {
            nil
        }
        
        try super.init(from: decoder)
    }
    
}
