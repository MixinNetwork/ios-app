import Foundation
import GRDB

public final class PerpsMarketCandlesDAO: PerpsDAO {
    
    public static let shared = PerpsMarketCandlesDAO()
    public static let perpsMarketCandleDidSaveNotification = Notification.Name(rawValue: "one.mixin.services.PerpsMarketCandlesDAO.Save")
    public static let candleUserInfoKey = "c"
    
    public func candle(product: String, timeFrame: String) -> PerpetualMarketCandle? {
        Self.candles[product]?[timeFrame]
    }
    
    public func save(candle: PerpetualMarketCandle) {
        var candles = Self.candles[candle.product] ?? [:]
        candles[candle.timeFrame] = candle
        Self.candles[candle.product] = candles
        NotificationCenter.default.post(
            onMainThread: Self.perpsMarketCandleDidSaveNotification,
            object: self,
            userInfo: [Self.candleUserInfoKey: candle]
        )
    }
    
}

extension PerpsMarketCandlesDAO {
    
    static var candles: [String: [String: PerpetualMarketCandle]] = [:]
    
}
