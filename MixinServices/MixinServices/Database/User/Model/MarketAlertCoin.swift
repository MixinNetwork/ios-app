import Foundation
import GRDB

public class MarketAlertCoin: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case coinID = "coin_id"
        case name
        case symbol = "symbol"
        case iconURL = "icon_url"
        case currentPrice = "current_price"
    }
    
    public let coinID: String
    public let name: String
    public let symbol: String
    public let iconURL: String
    public let currentPrice: String
    
    public private(set) lazy var decimalPrice = Decimal(string: currentPrice, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var localizedUSDPrice = CurrencyFormatter.localizedString(
        from: decimalPrice,
        format: .fiatMoneyPrice,
        sign: .never,
        symbol: .custom("USD")
    )
    
    public init(coinID: String, name: String, symbol: String, iconURL: String, currentPrice: String) {
        self.coinID = coinID
        self.name = name
        self.symbol = symbol
        self.iconURL = iconURL
        self.currentPrice = currentPrice
    }
    
    public convenience init(market: Market) {
        self.init(
            coinID: market.coinID,
            name: market.name,
            symbol: market.symbol,
            iconURL: market.iconURL,
            currentPrice: market.currentPrice
        )
    }
    
}
