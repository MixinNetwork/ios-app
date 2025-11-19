import Foundation
import GRDB

public final class MarketDAO: UserDatabaseDAO {
    
    public static let shared = MarketDAO()
    
    public static let favoriteNotification = Notification.Name("one.mixin.service.MarketDAO.Favorite")
    public static let unfavoriteNotification = Notification.Name("one.mixin.service.MarketDAO.Unfavorite")
    public static let didUpdateNotification = Notification.Name("one.mixin.service.MarketDAO.Update")
    
    public static let coinIDUserInfoKey = "cid"
    
    public func markets(
        category: Market.Category,
        order: Market.OrderingExpression,
        limit: Market.Limit?
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
        case .all:
            sql.append("\nINNER JOIN market_cap_ranks mcr ON m.coin_id = mcr.coin_id")
        case .favorite:
            sql.append("""
            
            LEFT JOIN market_cap_ranks mcr ON m.coin_id = mcr.coin_id
            WHERE mf.is_favored
            """)
        }
        sql.append("\nORDER BY CAST(ifnull(mcr.market_cap_rank, m.market_cap_rank) AS REAL) ASC")
        if let count = limit?.count {
            sql.append("\nLIMIT \(count)")
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
        case let .change(period, ordering):
            switch period {
            case .sevenDays:
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
            case .twentyFourHours:
                switch ordering {
                case .ascending:
                    results.sort { one, another in
                        one.decimalPriceChangePercentage24H < another.decimalPriceChangePercentage24H
                    }
                case .descending:
                    results.sort { one, another in
                        one.decimalPriceChangePercentage24H > another.decimalPriceChangePercentage24H
                    }
                }
            }
        }
        
        return results
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
            if let assetIDs = market.assetIDs, !assetIDs.isEmpty {
                let now = Date().toUTCString()
                let ids: [MarketID] = assetIDs.reduce(into: []) { result, assetID in
                    let id = MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
                    result.append(id)
                }
                try ids.save(db)
            }
            
            db.afterNextTransaction { _ in
                DispatchQueue.global().async {
                    NotificationCenter.default.post(
                        name: Self.didUpdateNotification,
                        object: self,
                        userInfo: [Self.coinIDUserInfoKey: market.coinID]
                    )
                }
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
    
    public func save(markets: [Market]) {
        try? db.writeAndReturnError { db in
            try markets.save(db)
            let now = Date().toUTCString()
            let ids: [MarketID] = markets.flatMap { market in
                market.assetIDs?.map { assetID in
                    MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
                } ?? []
            }
            try ids.save(db)
            
            db.afterNextTransaction { _ in
                DispatchQueue.global().async {
                    NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
                }
            }
        }
    }
    
    public func saveMarketsAndReplaceRanks(markets: [Market]) {
        let now = Date().toUTCString()
        let rankStorages = markets.compactMap(\.rankStorage)
        let ids: [MarketID] = markets.flatMap { market in
            market.assetIDs?.map { assetID in
                MarketID(coinID: market.coinID, assetID: assetID, createdAt: now)
            } ?? []
        }
        db.write { db in
            try markets.save(db)
            try db.execute(sql: "DELETE FROM market_cap_ranks")
            try rankStorages.save(db)
            try ids.save(db)
            
            db.afterNextTransaction { _ in
                DispatchQueue.global().async {
                    NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
                }
            }
        }
    }
    
    public func replaceFavoriteMarkets(markets: [Market]) {
        db.write { db in
            try markets.insert(db, onConflict: .replace)
            
            let distantPast = Date.distantPast.toUTCString()
            let favoredMarkets = try markets.map { market in
                let createdAt = try String.fetchOne(
                    db,
                    sql: "SELECT created_at FROM market_favored WHERE coin_id = ?",
                    arguments: [market.coinID]
                ) ?? distantPast
                return FavoredMarket(coinID: market.coinID, isFavored: true, createdAt: createdAt)
            }
            try db.execute(sql: "DELETE FROM market_favored")
            try favoredMarkets.save(db)
            
            db.afterNextTransaction { _ in
                DispatchQueue.global().async {
                    NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
                }
            }
        }
    }
    
    public func savePriceHistory(_ history: PriceHistoryStorage) {
        db.save(history)
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
