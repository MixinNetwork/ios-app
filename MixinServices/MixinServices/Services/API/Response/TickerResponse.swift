import Foundation

public struct TickerResponse: Codable {
    
    public let priceUsd: String
    
    enum CodingKeys: String, CodingKey {
        case priceUsd = "price_usd"
    }
    
}
