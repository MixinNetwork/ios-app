import Foundation

public struct TickerResponse: Codable {
    
    public let priceUsd: String
    
    public private(set) lazy var decimalUSDPrice = Decimal(string: priceUsd, locale: .enUSPOSIX) ?? 0
    
    enum CodingKeys: String, CodingKey {
        case priceUsd = "price_usd"
    }
    
}
