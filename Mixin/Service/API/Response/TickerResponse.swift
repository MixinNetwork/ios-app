import Foundation
import MixinServices

class TickerResponse: Codable {
    
    let priceUsd: String
    
    private(set) lazy var decimalUSDPrice = DecimalNumber(string: priceUsd) ?? 0
    
    enum CodingKeys: String, CodingKey {
        case priceUsd = "price_usd"
    }
    
}
