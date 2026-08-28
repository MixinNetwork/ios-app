import Foundation
import GRDB

public final class MarketDAO: UserDatabaseDAO {
    
    public enum DataSource {
        case all
        case favorite
        case categorized(Market.DatabaseCategory)
        case other
    }
    
    public enum UserInfoKey {
        public static let coinID = "cid"
        public static let coinIDs = "cids"
        public static let dataSource = "ds"
    }
    
    public static let shared = MarketDAO()
    
    public static let favoriteNotification = Notification.Name("one.mixin.service.MarketDAO.Favorite")
    public static let unfavoriteNotification = Notification.Name("one.mixin.service.MarketDAO.Unfavorite")
    public static let didUpdateNotification = Notification.Name("one.mixin.service.MarketDAO.Update")
    
    public func markets(
        category: Market.QueryCategory,
        order: Market.Ordering,
    ) -> [FavorableMarket] {
        let marketColumns: [String] = Market.CodingKeys.allCases.compactMap { key in
            if key == .marketCapRank {
                nil // `market_cap_rank` is selected from `market_cap_ranks`
            } else {
                "m." + key.rawValue
            }
        }
        var sql = """
        SELECT \(marketColumns.joined(separator: ", ")),
            ifnull(mcr.market_cap_rank, m.market_cap_rank) AS \(Market.CodingKeys.marketCapRank.rawValue),
            ifnull(mf.is_favored, FALSE) AS \(FavorableMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
        FROM markets m
            LEFT JOIN market_favored mf ON m.coin_id = mf.coin_id
            
        """
        switch category {
        case .watchlist, .trending, .topGainer, .topLoser, .stock:
            sql.append("LEFT JOIN market_cap_ranks mcr ON m.coin_id = mcr.coin_id")
        case .all:
            sql.append("INNER JOIN market_cap_ranks mcr ON m.coin_id = mcr.coin_id")
        }
        switch category {
        case .watchlist:
            sql.append("\nWHERE mf.is_favored")
        case .trending:
            sql.append("""

            INNER JOIN market_categories mc ON mc.coin_id = m.coin_id AND mc.category = \(Market.DatabaseCategory.trending.rawValue)
            """)
        case .topGainer:
            sql.append("""
            
            WHERE EXISTS (
                SELECT 1 FROM market_categories mc 
                WHERE mc.coin_id = m.coin_id AND mc.category = \(Market.DatabaseCategory.topGainer.rawValue)
            )
            """)
        case .topLoser:
            sql.append("""
            
            WHERE EXISTS (
                SELECT 1 FROM market_categories mc 
                WHERE mc.coin_id = m.coin_id AND mc.category = \(Market.DatabaseCategory.topLoser.rawValue)
            )
            """)
        case .stock:
            sql.append("""

            INNER JOIN market_categories mc ON mc.coin_id = m.coin_id AND mc.category = \(Market.DatabaseCategory.stock.rawValue)
            """)
        case .all:
            break
        }
        switch category {
        case .watchlist, .stock:
            break
        case .trending, .all:
            sql.append("\nWHERE m.coin_id NOT IN (SELECT coin_id FROM market_categories WHERE category = \(Market.DatabaseCategory.stock.rawValue))")
        case .topGainer, .topLoser:
            sql.append("\n    AND m.coin_id NOT IN (SELECT coin_id FROM market_categories WHERE category = \(Market.DatabaseCategory.stock.rawValue))")
        }
        switch order.field {
        case .marketCap:
            sql.append("\nORDER BY CAST(market_cap AS REAL)")
        case .volume:
            sql.append("\nORDER BY CAST(total_volume AS REAL)")
        case .price:
            sql.append("\nORDER BY CAST(current_price AS REAL)")
        case let .change(period):
            switch period {
            case .sevenDays:
                sql.append("\nORDER BY CAST(price_change_percentage_7d AS REAL)")
            case .twentyFourHours:
                sql.append("\nORDER BY CAST(price_change_percentage_24h AS REAL)")
            }
        case .rowid:
            sql.append("\nORDER BY mc.rowid")
        case .addedAt:
            sql.append("\nORDER BY mf.created_at")
        }
        switch order.direction {
        case .ascending:
            sql.append(" ASC")
        case .descending:
            sql.append(" DESC")
        }
        if order.field == .addedAt {
            sql.append(", mf.rowid ASC")
        }
        return db.select(with: sql)
    }
    
    public func watchlistRecommendations() -> [FavorableMarket] {
        let sql = """
        SELECT m.*
        FROM markets m
            INNER JOIN market_categories mc ON mc.coin_id = m.coin_id
        WHERE mc.category = \(Market.DatabaseCategory.featured.rawValue)
        """
        let markets: [Market] = db.select(with: sql)
        return markets.map { market in
            FavorableMarket(market: market, isFavorite: false)
        }
    }
    
    public func markets(keyword: String, limit: Int?) -> [FavorableMarket] {
        var sql = """
        SELECT m.*, ifnull(mf.is_favored, FALSE) AS \(FavorableMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
        FROM markets m
            LEFT JOIN market_favored mf ON m.coin_id = mf.coin_id
        WHERE (m.name LIKE :keyword OR m.symbol LIKE :keyword)
        ORDER BY CAST(m.market_cap_rank AS REAL) ASC
        """
        if let limit {
            sql += "\nLIMIT \(limit)"
        }
        return db.select(with: sql, arguments: ["keyword": "%\(keyword)%"])
    }
    
    public func market(coinID: String) -> FavorableMarket? {
        let sql = """
        SELECT m.*, ifnull(mf.is_favored, FALSE) AS \(FavorableMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
        FROM markets m
            LEFT JOIN market_favored mf ON m.coin_id = mf.coin_id
        WHERE m.coin_id = ?
        LIMIT 1
        """
        return db.select(with: sql, arguments: [coinID])
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
    
    public func inexistCoinIDs(in coinIDs: Set<String>) -> [String] {
        let values = coinIDs.map({ "('\($0)')" }).joined(separator: ",")
        return db.select(with: """
            WITH c(id) AS (VALUES \(values))
            SELECT c.id FROM c LEFT JOIN markets m ON c.id = m.coin_id WHERE m.coin_id IS NULL
        """)
    }
    
    public func priceChangePercentage24H(assetIDs: any Sequence<String>) -> [String: String] {
        try! db.read { (db) -> [String: String] in
            let query: GRDB.SQL = """
            SELECT mi.asset_id, m.price_change_percentage_24h
            FROM markets m
                LEFT JOIN market_ids mi ON m.coin_id = mi.coin_id
            WHERE mi.asset_id IN \(assetIDs)
            """
            let (sql, arguments) = try query.build(db)
            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            return rows.reduce(into: [:]) { results, row in
                if let key: String = row["asset_id"] {
                    results[key] = row["price_change_percentage_24h"]
                }
            }
        }
    }
    
    // Key is asset id, value is `current_price`
    public func currentPrices(assetIDs: [String]) -> [String: String] {
        try! db.read { (db) -> [String: String] in
            let query: GRDB.SQL = """
            SELECT mi.asset_id, m.current_price
            FROM markets m
                LEFT JOIN market_ids mi ON m.coin_id = mi.coin_id
            WHERE mi.asset_id IN \(assetIDs)
            """
            let (sql, arguments) = try query.build(db)
            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            return rows.reduce(into: [:]) { results, row in
                if let key: String = row["asset_id"] {
                    results[key] = row["current_price"]
                }
            }
        }
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
    
    @discardableResult
    public func save(market: Market) -> FavorableMarket? {
        try? db.writeAndReturnError { db in
            try market.save(db)
            
            try db.execute(
                sql: "DELETE FROM market_ids WHERE coin_id = ?",
                arguments: [market.coinID]
            )
            if let assetIDs = market.assetIDs, !assetIDs.isEmpty {
                let now = Date().toUTCString()
                let ids: [MarketID] = assetIDs.reduce(into: []) { result, assetID in
                    let id = MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
                    result.append(id)
                }
                try ids.save(db)
            }
            
            db.afterNextTransaction { _ in
                NotificationCenter.default.postAsynchornously(
                    onMainThread: Self.didUpdateNotification,
                    object: self,
                    userInfo: [Self.UserInfoKey.coinID: market.coinID]
                )
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
    
    public func save(
        markets: [Market],
        dataSource: DataSource,
    ) {
        let now = Date().toUTCString()
        let ids: [MarketID] = markets.flatMap { market in
            market.assetIDs?.map { assetID in
                MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
            } ?? []
        }
        db.write { db in
            try markets.save(db)
            
            try db.execute(
                literal: "DELETE FROM market_ids WHERE coin_id IN \(markets.map(\.coinID))"
            )
            try ids.save(db)
            
            switch dataSource {
            case .all:
                try db.execute(sql: "DELETE FROM market_cap_ranks")
                let rankStorages = markets.compactMap(\.rankStorage)
                try rankStorages.save(db)
            case .favorite:
                let favoritesStorage = markets.map { market in
                    Market.FavoriteStorage(
                        coinID: market.coinID,
                        isFavored: true,
                        createdAt: now
                    )
                }
                try db.execute(sql: "DELETE FROM market_favored")
                try favoritesStorage.save(db)
            case .categorized(let category):
                try db.execute(
                    sql: "DELETE FROM market_categories WHERE category = ?",
                    arguments: [category.rawValue]
                )
                let categoriesStorage = markets.map { market in
                    Market.CategoryStorage(coinID: market.coinID, category: category)
                }
                try categoriesStorage.save(db)
            case .other:
                break
            }
            
            db.afterNextTransaction { _ in
                NotificationCenter.default.postAsynchornously(
                    onMainThread: Self.didUpdateNotification,
                    object: self,
                    userInfo: [UserInfoKey.dataSource: dataSource]
                )
            }
        }
    }
    
    public func savePriceHistory(_ history: PriceHistoryStorage) {
        db.save(history)
    }
    
    public func favorableMarket(markets: any Sequence<Market>) -> [FavorableMarket] {
        let favoriteCoinIDs: Set<String> = db.selectSet(
            with: "SELECT coin_id FROM market_favored WHERE is_favored"
        )
        return markets.map { market in
            FavorableMarket(market: market, isFavorite: favoriteCoinIDs.contains(market.coinID))
        }
    }
    
    public func favorite(coinIDs: [String], completion: (() -> Void)? = nil) {
        let now = Date().toUTCString()
        let favorites = coinIDs.map { coinID in
            Market.FavoriteStorage(
                coinID: coinID,
                isFavored: true,
                createdAt: now
            )
        }
        db.save(favorites) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.favoriteNotification,
                    object: self,
                    userInfo: [UserInfoKey.coinIDs: coinIDs]
                )
                completion?()
            }
        }
    }
    
    public func unfavorite(coinIDs: [String], completion: (() -> Void)? = nil) {
        let update: GRDB.SQL = "UPDATE market_favored SET is_favored = FALSE WHERE coin_id IN \(coinIDs)"
        db.execute(query: update) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.unfavoriteNotification,
                    object: self,
                    userInfo: [UserInfoKey.coinIDs: coinIDs]
                )
                completion?()
            }
        }
    }
    
    public func delete(coinID: String) {
        db.write { db in
            try db.execute(
                sql: "DELETE FROM markets WHERE coin_id = ?",
                arguments: [coinID]
            )
            try db.execute(
                sql: "DELETE FROM market_ids WHERE coin_id = ?",
                arguments: [coinID]
            )
            try db.execute(
                sql: "DELETE FROM market_cap_ranks WHERE coin_id = ?",
                arguments: [coinID]
            )
            try db.execute(
                sql: "DELETE FROM market_favored WHERE coin_id = ?",
                arguments: [coinID]
            )
            try db.execute(
                sql: "DELETE FROM market_categories WHERE coin_id = ?",
                arguments: [coinID]
            )
        }
    }
    
    public func deleteOrphanRecords() {
        db.execute(sql: """
        DELETE FROM markets
        WHERE coin_id NOT IN (SELECT coin_id FROM market_cap_ranks)
            AND coin_id NOT IN (SELECT DISTINCT coin_id FROM market_categories)
            AND NOT EXISTS (
                SELECT 1 
                FROM market_favored 
                WHERE market_favored.coin_id = markets.coin_id AND is_favored = TRUE
            )
        """)
    }
    
    public func deleteAll() {
        db.write { db in
            try db.execute(sql: "DELETE FROM markets")
            try db.execute(sql: "DELETE FROM market_cap_ranks")
            try db.execute(sql: "DELETE FROM market_categories")
            try db.execute(sql: "DELETE FROM market_ids")
            try db.execute(sql: "DELETE FROM market_favored")
        }
    }
    
}
