import Foundation
import GRDB

public struct MarketAlertCoin {
    
    public let coinID: String
    public let name: String
    public let symbol: String
    public let iconURL: String
    public let currentPrice: String
    
    public init(coinID: String, name: String, symbol: String, iconURL: String, currentPrice: String) {
        self.coinID = coinID
        self.name = name
        self.symbol = symbol
        self.iconURL = iconURL
        self.currentPrice = currentPrice
    }
    
}

extension MarketAlertCoin: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case coinID = "coin_id"
        case name
        case symbol = "symbol"
        case iconURL = "icon_url"
        case currentPrice = "current_price"
    }
    
}
