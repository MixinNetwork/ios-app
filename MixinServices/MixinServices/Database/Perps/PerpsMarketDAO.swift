import Foundation
import GRDB

public final class PerpsMarketDAO: PerpsDAO {
    
    public struct Ordering: Equatable {
        
        public enum Direction {
            case ascending
            case descending
        }
        
        public enum Field {
            case volume
            case price
            case change
        }
        
        public let field: Field
        public let direction: Direction
        
        public init(field: Field, direction: Direction) {
            self.field = field
            self.direction = direction
        }
        
    }
    
    public static let shared = PerpsMarketDAO()
    
    public static let marketsDidUpdateNotification = Notification.Name(rawValue: "one.mixin.services.PerpsMarketDAO.Update")
    
    public func market(marketID: String) -> PerpetualMarket? {
        db.select(with: "SELECT * FROM markets WHERE market_id = ?", arguments: [marketID])
    }
    
    public func availableMarkets(
        ordering: Ordering?,
        limit: Int?
    ) -> [PerpetualMarket] {
        var sql = "SELECT * FROM markets WHERE volume > 0"
        if let ordering {
            switch ordering.field {
            case .volume:
                sql += " ORDER BY CAST(volume AS REAL)"
            case .price:
                sql += " ORDER BY CAST(last AS REAL)"
            case .change:
                sql += " ORDER BY ABS(CAST(change AS REAL))"
            }
            switch ordering.direction {
            case .ascending:
                sql += " ASC"
            case .descending:
                sql += " DESC"
            }
        } else {
            sql += " ORDER BY rowid ASC"
        }
        if let limit {
            sql += " LIMIT \(limit)"
        }
        return db.select(with: sql)
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
