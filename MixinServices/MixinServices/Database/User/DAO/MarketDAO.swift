import Foundation
import GRDB

public final class MarketDAO: UserDatabaseDAO {
    
    public static let shared = MarketDAO()
    
    public func saveMarket(_ market: Market) {
        db.save(market)
    }
    
    public func savePriceHistory(_ history: PriceHistory) {
        db.save(history)
    }
    
    public func market(assetID: String) -> Market? {
        db.select(where: Market.column(of: .assetID) == assetID)
    }
    
    public func priceHistory(assetID: String, period: PriceHistory.Period) -> PriceHistory? {
        db.select(where: PriceHistory.column(of: .assetID) == assetID && PriceHistory.column(of: .period) == period.rawValue)
    }
    
}
