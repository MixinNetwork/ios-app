import Foundation
import MixinServices

struct TokenPrice {
    
    let key: String
    let period: PriceHistory.Period
    let prices: [Price]
    let updateAt: String
    
    init?(priceHistory: PriceHistory) {
        if let data = priceHistory.data.data(using: .utf8),
           let prices = try? JSONDecoder.default.decode([Price].self, from: data)
        {
            self.key = priceHistory.assetID
            self.period = priceHistory.period
            self.prices = prices
            self.updateAt = priceHistory.updateAt
        } else {
            return nil
        }
    }
    
    func asPriceHistory() -> PriceHistory? {
        if let data = try? JSONEncoder.default.encode(prices),
           let string = String(data: data, encoding: .utf8)
        {
            PriceHistory(assetID: key, period: period, data: string, updateAt: updateAt)
        } else {
            nil
        }
    }
    
    func chartViewPoints() -> [ChartView.Point] {
        prices.compactMap { price in
            guard let decimalPrice = Decimal(string: price.price, locale: .enUSPOSIX) else {
                return nil
            }
            let date = Date(timeIntervalSince1970: TimeInterval(price.timestamp) / 1000)
            return ChartView.Point(date: date, value: decimalPrice)
        }
    }
    
}

extension TokenPrice: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case key = "key"
        case period = "type"
        case prices = "data"
        case updateAt = "updated_at"
    }
    
    struct Price: Codable {
        
        enum CodingKeys: String, CodingKey {
            case price = "price"
            case timestamp = "unix"
        }
        
        let price: String
        let timestamp: Int
        
    }
    
}