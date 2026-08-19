import Foundation
import GRDB

public final class PerpsMarketDAO: PerpsDAO {
    
    public enum UserInfoKey {
        public static let market = "m"
        public static let marketIDs = "mids"
        public static let dataSource = "ds"
    }
    
    public static let shared = PerpsMarketDAO()
    
    public static let marketsDidUpdateNotification = Notification.Name(rawValue: "one.mixin.services.PerpsMarketDAO.Update")
    public static let favoriteNotification = Notification.Name("one.mixin.service.PerpsMarketDAO.Favorite")
    public static let unfavoriteNotification = Notification.Name("one.mixin.service.PerpsMarketDAO.Unfavorite")
    
    public func market(marketID: String) -> PerpetualMarket? {
        db.select(with: "SELECT * FROM markets WHERE market_id = ?", arguments: [marketID])
    }
    
    public func price(marketID: String) -> String? {
        db.select(with: "SELECT last FROM markets WHERE market_id = ?", arguments: [marketID])
    }
    
    public func availableTopMovers(
        count: Int
    ) -> [PerpetualMarket] {
        let gainers: [PerpetualMarket] = availableMarkets(
            category: .all,
            ordering: .init(field: .change, direction: .descending),
            limit: count
        )
        let losers: [PerpetualMarket] = availableMarkets(
            category: .all,
            ordering: .init(field: .change, direction: .ascending),
            limit: count
        )
        return gainers + losers
    }
    
    public func availableMarkets(
        category: PerpetualMarket.QueryCategory,
        ordering: PerpetualMarket.Ordering,
        limit: Int? = nil,
    ) -> [FavorablePerpetualMarket] {
        var sql = """
        SELECT m.*,
            ifnull(f.is_favored, FALSE) AS \(FavorablePerpetualMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
        FROM markets m
            LEFT JOIN favorites f ON m.market_id = f.market_id
        WHERE m.volume > 0
            
        """
        switch category {
        case .watchlist:
            sql.append("    AND f.is_favored")
        case .all:
            break
        case .categorized(let category):
            sql.append("    AND m.category = '\(category.rawValue)'")
        }
        let direction = switch ordering.direction {
        case .ascending:
            "ASC"
        case .descending:
            "DESC"
        }
        switch ordering.field {
        case .volume:
            sql += "\nORDER BY CAST(volume AS REAL) \(direction)"
        case .price:
            sql += "\nORDER BY CAST(last AS REAL) \(direction)"
        case .change:
            sql += "\nORDER BY CAST(change AS REAL) \(direction)"
        case .score:
            sql += "\nORDER BY trade_volume_score_1d \(direction), CAST(volume AS REAL) \(direction)"
        }
        if let limit {
            sql += "\nLIMIT \(limit)"
        }
        return db.select(with: sql)
    }
    
    public func watchlistRecommendations() -> [FavorablePerpetualMarket] {
        let sql = """
        SELECT m.*
        FROM markets m
            INNER JOIN market_categories mc ON mc.market_id = m.market_id
        WHERE mc.category = \(Market.DatabaseCategory.featured.rawValue)
        """
        let markets: [PerpetualMarket] = db.select(with: sql)
        return markets.map { market in
            FavorablePerpetualMarket(market: market, isFavorite: false)
        }
    }
    
    public func save(market: PerpetualMarket) {
        db.save(market) { _ in
            NotificationCenter.default.postAsynchornously(
                onMainThread: Self.marketsDidUpdateNotification,
                object: self,
                userInfo: [UserInfoKey.market: market],
            )
        }
    }
    
    public func save(
        markets: [PerpetualMarket],
        dataSource: PerpetualMarket.RequestCategory,
    ) {
        guard !markets.isEmpty else {
            return
        }
        db.write { db in
            switch dataSource {
            case .all:
                try markets.save(db)
            case .favorite:
                try db.execute(literal: "DELETE FROM favorites WHERE market_id NOT IN \(markets.map(\.marketID))")
                let now = Date().toUTCString()
                for market in markets {
                    _ = try market.upsertAndFetch(db) { _ in
                        [PerpetualMarket.column(of: .tradeVolumeScore1D).noOverwrite]
                    }
                    let favorite = PerpetualMarket.FavoriteStorage(
                        marketID: market.marketID,
                        isFavorite: true,
                        createdAt: now,
                    )
                    try favorite.save(db)
                }
            case .featured:
                try db.execute(literal: "DELETE FROM market_categories WHERE category = \(Market.DatabaseCategory.featured.rawValue)")
                for market in markets {
                    _ = try market.upsertAndFetch(db) { _ in
                        [PerpetualMarket.column(of: .tradeVolumeScore1D).noOverwrite]
                    }
                    let category = PerpetualMarketCategory(marketID: market.marketID, category: .featured)
                    try category.save(db)
                }
            }
            db.afterNextTransaction { _ in
                NotificationCenter.default.postAsynchornously(
                    onMainThread: Self.marketsDidUpdateNotification,
                    object: self,
                    userInfo: [UserInfoKey.dataSource: dataSource]
                )
            }
        }
    }
    
    public func isFavorite(marketID: String) -> Bool {
        let sql = """
        SELECT ifnull(is_favored, FALSE)
        FROM favorites
        WHERE market_id = ?
        """
        let value: Int? = db.select(with: sql, arguments: [marketID])
        return value == 1
    }
    
    public func favorite(marketIDs: [String], completion: (() -> Void)? = nil) {
        let favorites = marketIDs.map { marketID in
            PerpetualMarket.FavoriteStorage(
                marketID: marketID,
                isFavorite: true,
                createdAt: Date().toUTCString()
            )
        }
        db.save(favorites) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.favoriteNotification,
                    object: self,
                    userInfo: [Self.UserInfoKey.marketIDs: marketIDs]
                )
                completion?()
            }
        }
    }
    
    public func unfavorite(marketIDs: [String], completion: (() -> Void)? = nil) {
        let update: GRDB.SQL = "UPDATE favorites SET is_favored = FALSE WHERE market_id IN \(marketIDs)"
        db.execute(query: update) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.unfavoriteNotification,
                    object: self,
                    userInfo: [Self.UserInfoKey.marketIDs: marketIDs]
                )
                completion?()
            }
        }
    }
    
    public func deleteAll() {
        db.write { db in
            try db.execute(sql: "DELETE FROM markets")
            try db.execute(sql: "DELETE FROM market_categories")
            try db.execute(sql: "DELETE FROM favorites")
        }
    }
    
}
