import Foundation
import GRDB

public final class PerpsMarketDAO: PerpsDAO {
    
    public enum UserInfoKey {
        public static let market = "m"
        public static let marketIDs = "mids"
    }
    
    public enum Metadata {
        case favorite
        case category(Market.DatabaseCategory)
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
        let risings: [PerpetualMarket] = db.select(with: """
        SELECT * FROM markets
        WHERE volume > 0
        ORDER BY CAST(change AS REAL) DESC
        LIMIT \(count)
        """)
        let fallings:  [PerpetualMarket] = db.select(with: """
        SELECT * FROM markets
        WHERE volume > 0
        ORDER BY CAST(change AS REAL) ASC
        LIMIT \(count)
        """)
        return risings + fallings
    }
    
    public func availableMarkets(
        ordering: MarketOrdering?,
        category: PerpetualMarket.Category?,
        limit: Int?
    ) -> [FavorablePerpetualMarket] {
        var sql = """
        SELECT m.*,
            ifnull(f.is_favored, FALSE) AS '\(FavorablePerpetualMarket.JoinedQueryCodingKeys.isFavorite.rawValue)'
        FROM markets m
            LEFT JOIN favorites f ON m.market_id = f.market_id
        WHERE m.volume > 0
        """
        if let category {
            sql += " AND m.category = '\(category.rawValue)'"
        }
        if let ordering {
            switch ordering.field {
            case .marketCap:
                assertionFailure("No market capitalization ordering in perps")
                sql += "\nORDER BY m.rowid"
            case .volume:
                sql += "\nORDER BY CAST(m.volume AS REAL)"
            case .price:
                sql += "\nORDER BY CAST(m.last AS REAL)"
            case .change:
                sql += "\nORDER BY CAST(m.change AS REAL)"
            }
            switch ordering.direction {
            case .ascending:
                sql += " ASC"
            case .descending:
                sql += " DESC"
            }
        } else {
            sql += "\nORDER BY m.rowid ASC"
        }
        if let limit {
            sql += "\nLIMIT \(limit)"
        }
        return db.select(with: sql)
    }
    
    public func availableMarkets(
        subCategory: PerpetualMarket.SubCategory,
        ordering: MarketOrdering?,
    ) -> [FavorablePerpetualMarket] {
        var sql = """
        SELECT m.*,
            ifnull(f.is_favored, FALSE) AS \(FavorablePerpetualMarket.JoinedQueryCodingKeys.isFavorite.rawValue)
        FROM markets m
            LEFT JOIN favorites f ON m.market_id = f.market_id
        WHERE volume > 0
            
        """
        switch subCategory {
        case .watchlist:
            sql.append("AND f.is_favored")
        case .trending:
            break
        case .topGainers:
            break
        case .topLosers:
            break
        case .memes:
            sql.append("AND m.category = '\(PerpetualMarket.Category.memes.rawValue)'")
        case .indices:
            sql.append("AND m.category = '\(PerpetualMarket.Category.indices.rawValue)'")
        case .commodities:
            sql.append("AND m.category = '\(PerpetualMarket.Category.commodities.rawValue)'")
        case .forex:
            sql.append("AND m.category = '\(PerpetualMarket.Category.forex.rawValue)'")
        }
        if let ordering {
            switch ordering.field {
            case .marketCap:
                assertionFailure("No market capitalization ordering in perps")
                sql += "\nORDER BY rowid"
            case .volume:
                sql += "\nORDER BY CAST(volume AS REAL)"
            case .price:
                sql += "\nORDER BY CAST(last AS REAL)"
            case .change:
                sql += "\nORDER BY CAST(change AS REAL)"
            }
            switch ordering.direction {
            case .ascending:
                sql += " ASC"
            case .descending:
                sql += " DESC"
            }
        } else {
            sql += "\nORDER BY CAST(volume AS REAL) DESC"
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
        updatingMetadata: Metadata?,
    ) {
        guard !markets.isEmpty else {
            return
        }
        db.write { db in
            try markets.save(db)
            switch updatingMetadata {
            case .favorite:
                try db.execute(literal: "DELETE FROM favorites WHERE market_id NOT IN \(markets.map(\.marketID))")
                for market in markets {
                    let favorite = PerpetualMarket.FavoriteStorage(
                        marketID: market.marketID,
                        isFavorite: true,
                        createdAt: Date().toUTCString()
                    )
                    try favorite.save(db, onConflict: .ignore)
                }
            case .category(let category):
                switch category {
                case .featured:
                    try db.execute(literal: "DELETE FROM market_categories WHERE category = \(Market.DatabaseCategory.featured.rawValue)")
                    let categories = markets.map { market in
                        PerpetualMarketCategory(marketID: market.marketID, category: .featured)
                    }
                    try categories.save(db)
                default:
                    // Not available for now
                    break
                }
            case .none:
                break
            }
            db.afterNextTransaction { _ in
                NotificationCenter.default.postAsynchornously(
                    onMainThread: Self.marketsDidUpdateNotification,
                    object: self
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
