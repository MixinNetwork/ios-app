import Foundation
import GRDB

public final class MarketDAO: UserDatabaseDAO {
    
    public static let shared = MarketDAO()
    
    public func markets(
        category: Market.Category,
        order: Market.OrderingExpression,
        limit: Market.Limit
    ) -> [FavorableMarket] {
        var sql = """
        SELECT m.*, ifnull(mf.is_favored, FALSE) AS \(FavorableMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
        FROM markets m
            LEFT JOIN market_favored mf ON m.coin_id = mf.coin_id
        """
        switch category {
        case .all:
            break
        case .favorite:
            sql += "\nWHERE mf.is_favored"
        }
        switch order {
        case .marketCap(.ascending):
            sql += "\nORDER BY CAST(m.market_cap AS REAL) ASC"
        case .marketCap(.descending):
            sql += "\nORDER BY CAST(m.market_cap AS REAL) DESC"
        case .price(.ascending):
            sql += "\nORDER BY CAST(m.current_price AS REAL) ASC"
        case .price(.descending):
            sql += "\nORDER BY CAST(m.current_price AS REAL) DESC"
        case .change(.ascending):
            sql += "\nORDER BY ABS(CAST(m.price_change_percentage_24h AS REAL)) ASC"
        case .change(.descending):
            sql += "\nORDER BY ABS(CAST(m.price_change_percentage_24h AS REAL)) DESC"
        }
        sql += "\nLIMIT \(limit.count)"
        return db.select(with: sql)
    }
    
    public func market(assetID: String) -> Market? {
        let sql = """
        SELECT m.*
        FROM markets m
            LEFT JOIN market_ids mi ON m.coin_id = mi.coin_id
        WHERE mi.asset_id = ?
        LIMIT 1
        """
        return db.select(with: sql, arguments: [assetID])
    }
    
    public func priceHistory(assetID: String, period: PriceHistory.Period) -> PriceHistory? {
        db.select(where: PriceHistory.column(of: .assetID) == assetID && PriceHistory.column(of: .period) == period.rawValue)
    }
    
    public func save(market: Market) {
        db.save(market)
        if let assetIDs = market.assetIDs {
            let now = Date().toUTCString()
            let ids: [MarketID] = assetIDs.reduce(into: []) { result, assetID in
                let id = MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
                result.append(id)
            }
            db.save(ids)
        }
    }
    
    public func save(markets: [Market], completion: @escaping () -> Void) {
        let now = Date().toUTCString()
        let ids: [MarketID] = markets.reduce(into: []) { result, market in
            guard let assetIDs = market.assetIDs else {
                return
            }
            let ids: [MarketID] = assetIDs.reduce(into: []) { result, assetID in
                let id = MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
                result.append(id)
            }
            result.append(contentsOf: ids)
        }
        db.save(ids)
        db.save(markets) { _ in
            completion()
        }
    }
    
    public func savePriceHistory(_ history: PriceHistory) {
        db.save(history)
    }
    
    public func saveFavoredMarkets(_ favoredMarkets: [FavoredMarket]) {
        db.save(favoredMarkets)
    }
    
    public func favorite(coinID: String) {
        let market = FavoredMarket(coinID: coinID, isFavored: true, createdAt: Date().toUTCString())
        db.save(market)
    }
    
    public func unfavorite(coinID: String) {
        let sql = "UPDATE market_favored SET is_favored = FALSE WHERE coin_id = ?"
        db.execute(sql: sql, arguments: [coinID])
    }
    
}
