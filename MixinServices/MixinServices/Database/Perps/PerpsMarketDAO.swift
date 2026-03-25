import Foundation
import GRDB

public final class PerpsMarketDAO: PerpsDAO {
    
    public static let shared = PerpsMarketDAO()
    
    public static let marketsDidUpdateNotification = Notification.Name(rawValue: "one.mixin.services.PerpsMarketDAO.Update")
    
    public func market(marketID: String) -> PerpetualMarket? {
        db.select(with: "SELECT * FROM markets WHERE market_id = ?", arguments: [marketID])
    }
    
    public func availableMarkets() -> [PerpetualMarket] {
        db.select(with: "SELECT * FROM markets WHERE volume > 0")
    }
    
    public func save(market: PerpetualMarket) {
        db.save(market) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.marketsDidUpdateNotification,
                    object: self
                )
            }
        }
    }
    
    public func save(markets: [PerpetualMarket]) {
        db.save(markets) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.marketsDidUpdateNotification,
                    object: self
                )
            }
        }
    }
    
}
