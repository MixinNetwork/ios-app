import Foundation
import MixinServices

struct PriceHistory {
    
    let coinID: String
    let period: PriceHistoryPeriod
    let prices: [Price]
    let updateAt: String
    
    init?(storage: PriceHistoryStorage) {
        if let data = storage.data.data(using: .utf8),
           let prices = try? JSONDecoder.default.decode([Price].self, from: data)
        {
            self.coinID = storage.coinID
            self.period = storage.period
            self.prices = prices
            self.updateAt = storage.updateAt
        } else {
            return nil
        }
    }
    
    func asStorage() -> PriceHistoryStorage? {
        if let data = try? JSONEncoder.default.encode(prices),
           let string = String(data: data, encoding: .utf8)
        {
            PriceHistoryStorage(coinID: coinID, period: period, data: string, updateAt: updateAt)
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

extension PriceHistory: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case coinID = "coin_id"
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
