import Foundation

struct TickerResponse: Codable {
    
    let priceUsd: String
    
    enum CodingKeys: String, CodingKey {
        case priceUsd = "price_usd"
    }
    
}
