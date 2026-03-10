import Foundation
import GRDB

public final class PerpsMarketDAO: PerpsDAO {
    
    public static let shared = PerpsMarketDAO()
    
    public func market(marketID: String) -> PerpetualMarket? {
        db.select(with: "SELECT * FROM markets WHERE market_id = ?", arguments: [marketID])
    }
    
    public func markets() -> [PerpetualMarket] {
        db.select(with: "SELECT * FROM markets")
    }
    
    public func replace(markets: [PerpetualMarket]) {
        db.save(markets)
    }
    
}
