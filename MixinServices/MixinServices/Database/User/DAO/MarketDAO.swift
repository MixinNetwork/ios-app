import Foundation
import GRDB

public final class MarketDAO: UserDatabaseDAO {
    
    public static let shared = MarketDAO()
    
    public static let favoriteNotification = Notification.Name("one.mixin.service.MarketDAO.Favorite")
    public static let unfavoriteNotification = Notification.Name("one.mixin.service.MarketDAO.Unfavorite")
    
    public static let coinIDUserInfoKey = "cid"
    
    public func markets(
        category: Market.Category,
        order: Market.OrderingExpression,
        limit: Market.Limit?
    ) -> [FavorableMarket] {
        var sql = """
        SELECT m.*, ifnull(mf.is_favored, FALSE) AS \(FavorableMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
        FROM markets m
            INNER JOIN market_cap_ranks mcr ON m.coin_id = mcr.coin_id
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
    
    public func market(assetID: String) -> FavorableMarket? {
        let sql = """
        SELECT m.*, ifnull(mf.is_favored, FALSE) AS \(FavorableMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
        FROM markets m
            LEFT JOIN market_ids mi ON m.coin_id = mi.coin_id
            LEFT JOIN market_favored mf ON m.coin_id = mf.coin_id
        WHERE mi.asset_id = ?
        LIMIT 1
        """
        return db.select(with: sql, arguments: [assetID])
    }
    
    public func inexistCoinIDs(in coinIDs: [String]) -> [String] {
        let values = coinIDs.map({ "('\($0)')" }).joined(separator: ",")
        return db.select(with: """
            WITH c(id) AS (VALUES \(values))
            SELECT c.id FROM c LEFT JOIN markets m ON c.id = m.coin_id WHERE m.coin_id IS NULL
        """)
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
    
    public func allMarketAlertCoins() -> [MarketAlertCoin] {
        db.select(with: "SELECT m.coin_id, m.name, m.symbol, m.icon_url, m.current_price FROM markets m")
    }
    
    public func marketAlertCoins(coinIDs ids: [String]) -> [MarketAlertCoin] {
        guard !ids.isEmpty else {
            return allMarketAlertCoins()
        }
        var query: GRDB.SQL = """
            SELECT m.coin_id, m.name, m.symbol, m.icon_url, m.current_price
            FROM markets m
            WHERE m.coin_id IN \(ids)
        """
        return db.select(with: query)
    }
    
    public func save(market: Market) -> FavorableMarket? {
        try? db.writeAndReturnError { db in
            try market.save(db)
            if let assetIDs = market.assetIDs, !assetIDs.isEmpty {
                let now = Date().toUTCString()
                let ids: [MarketID] = assetIDs.reduce(into: []) { result, assetID in
                    let id = MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
                    result.append(id)
                }
                try ids.save(db)
            }
            
            let sql = """
            SELECT m.*, ifnull(mf.is_favored, FALSE) AS \(FavorableMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
            FROM markets m
                LEFT JOIN market_favored mf ON m.coin_id = mf.coin_id
            WHERE m.coin_id = ?
            LIMIT 1
            """
            let favorableMarket = try FavorableMarket.fetchOne(db, sql: sql, arguments: [market.coinID])
            return favorableMarket
        }
    }
    
    public func replaceMarkets(with markets: [Market], completion: @escaping () -> Void) {
        let now = Date().toUTCString()
        let rankStorages = markets.map(\.rankStorage)
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
            try markets.save(db)
            try db.execute(sql: "DELETE FROM market_cap_ranks")
            try rankStorages.save(db)
            try ids.save(db)
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
    
    public func favorite(coinID: String, sendNotification: Bool) {
        let market = FavoredMarket(coinID: coinID, isFavored: true, createdAt: Date().toUTCString())
        db.save(market) { _ in
            guard sendNotification else {
                return
            }
            DispatchQueue.global().async {
                NotificationCenter.default.post(name: Self.favoriteNotification,
                                                object: self,
                                                userInfo: [Self.coinIDUserInfoKey: coinID])
            }
        }
    }
    
    public func unfavorite(coinID: String, sendNotification: Bool) {
        let sql = "UPDATE market_favored SET is_favored = FALSE WHERE coin_id = ?"
        db.execute(sql: sql, arguments: [coinID]) { _ in
            guard sendNotification else {
                return
            }
            DispatchQueue.global().async {
                NotificationCenter.default.post(name: Self.unfavoriteNotification,
                                                object: self,
                                                userInfo: [Self.coinIDUserInfoKey: coinID])
            }
        }
    }
    
}
