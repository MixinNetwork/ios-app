import Foundation

public struct PerpetualMarketCandle: Codable {
    
    public let marketID: String
    public let timeFrame: String
    public let items: [Item]
    public let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case marketID = "market_id"
        case timeFrame = "time_frame"
        case items = "items"
        case updatedAt = "updated_at"
    }
    
}

extension PerpetualMarketCandle {
    
    public struct Item: Codable {
        
        public let timestamp: Int
        public let open: String
        public let high: String
        public let low: String
        public let close: String
        public let volume: String
        public let amount: String
        public let count: Int
        public let tradeID: Int
        
        enum CodingKeys: String, CodingKey {
            case timestamp = "timestamp"
            case open = "open"
            case high = "high"
            case low = "low"
            case close = "close"
            case volume = "volume"
            case amount = "amount"
            case count = "count"
            case tradeID = "trade_id"
        }
        
    }
    
}
