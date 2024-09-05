import Foundation
import GRDB

public final class MarketDAO: UserDatabaseDAO {
    
    public static let shared = MarketDAO()
    
    public func markets(
        category: Market.Category,
        order: Market.OrderingExpression,
        limit: Market.Limit?
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
        sql += "\nORDER BY CAST(m.market_cap AS REAL) DESC"
        if let count = limit?.count {
            sql += "\nLIMIT \(count)"
        }
        var results: [FavorableMarket] = db.select(with: sql)
        
        switch order {
        case let .marketCap(ordering):
            switch ordering {
            case .ascending:
                results.reverse()
            case .descending:
                break
            }
        case let .price(ordering):
            switch ordering {
            case .ascending:
                results.sort { one, another in
                    one.decimalPrice < another.decimalPrice
                }
            case .descending:
                results.sort { one, another in
                    one.decimalPrice > another.decimalPrice
                }
            }
        case let .change(ordering):
            switch ordering {
            case .ascending:
                results.sort { one, another in
                    one.decimalPriceChangePercentage7D < another.decimalPriceChangePercentage7D
                }
            case .descending:
                results.sort { one, another in
                    one.decimalPriceChangePercentage7D > another.decimalPriceChangePercentage7D
                }
            }
        }
        
        return results
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
    
    public func priceHistory(coinID: String, period: PriceHistoryPeriod) -> PriceHistoryStorage? {
        let sql = """
        SELECT hp.*
        FROM history_prices hp
        WHERE hp.coin_id = ? AND hp.type = ?
        LIMIT 1
        """
        return db.select(with: sql, arguments: [coinID, period.rawValue])
    }
    
    public func priceHistory(assetID: String, period: PriceHistoryPeriod) -> PriceHistoryStorage? {
        let sql = """
        SELECT hp.*
        FROM history_prices hp
            LEFT JOIN market_ids mi ON hp.coin_id = mi.coin_id
        WHERE mi.asset_id = ? AND hp.type = ?
        LIMIT 1
        """
        return db.select(with: sql, arguments: [assetID, period.rawValue])
    }
    
    public func save(market: Market) {
        db.write { db in
            // When a single Market object is requested, its `marketCapRank` may differ from
            // the value in the `markets` table. This can result in duplicate ranks when
            // querying the market list. To avoid this issue, retrieve the known rank for
            // this record and overwrite it.
            let existedRank: String? = try Market
                .select(Market.column(of: .marketCapRank))
                .filter(Market.column(of: .coinID) == market.coinID)
                .fetchOne(db)
            let rankReplacedMarket = market.replacingMarketCapRank(with: existedRank ?? "")
            try rankReplacedMarket.save(db)
            if let assetIDs = market.assetIDs, !assetIDs.isEmpty {
                let now = Date().toUTCString()
                let ids: [MarketID] = assetIDs.reduce(into: []) { result, assetID in
                    let id = MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
                    result.append(id)
                }
                try ids.save(db)
            }
        }
    }
    
    public func replaceMarkets(with markets: [Market], completion: @escaping () -> Void) {
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
        db.write { db in
            try db.execute(sql: "DELETE FROM markets")
            try ids.save(db)
            try markets.save(db)
            db.afterNextTransaction { _ in
                completion()
            }
        }
    }
    
    public func savePriceHistory(_ history: PriceHistoryStorage) {
        db.save(history)
    }
    
    public func replaceFavoredMarkets(
        with favoredMarkets: [FavoredMarket],
        completion: @escaping () -> Void
    ) {
        db.write { db in
            try db.execute(sql: "DELETE FROM market_favored")
            try favoredMarkets.save(db)
            db.afterNextTransaction { _ in
                completion()
            }
        }
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
