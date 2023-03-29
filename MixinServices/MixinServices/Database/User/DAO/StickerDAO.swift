import GRDB

public final class StickerDAO: UserDatabaseDAO {
    
    public static let favoriteStickersDidChangeNotification = NSNotification.Name("one.mixin.services.StickerDAO.favoriteStickersDidChange")
    
    private static let sqlQueryColumns = """
    SELECT s.sticker_id, s.name, s.asset_url, s.asset_type, s.asset_width, s.asset_height, s.last_used_at, a.category, a.added, s.album_id
    FROM stickers s
    """
    private static let relationShipJoinClause = "INNER JOIN sticker_relationships sa ON sa.sticker_id = s.sticker_id"
    private static let albumJoinClause = "INNER JOIN albums a ON a.album_id = sa.album_id"
    private static let sqlQuerySticker = """
    \(sqlQueryColumns)
    \(relationShipJoinClause) AND sa.album_id = ?
    \(albumJoinClause)
    WHERE s.name = ?
    LIMIT 1
    """
    private static let sqlQueryStickersByAlbum = """
    \(sqlQueryColumns)
    \(relationShipJoinClause) AND sa.album_id = ?
    \(albumJoinClause)
    ORDER BY sa.created_at DESC
    """
    private static let sqlQueryFavoriteStickers = """
    \(sqlQueryColumns)
    \(relationShipJoinClause)
    \(albumJoinClause) AND a.category = 'PERSONAL'
    ORDER BY sa.created_at DESC
    """
    private static let sqlQueryStickerByStickerId = """
    \(sqlQueryColumns)
    \(relationShipJoinClause)
    \(albumJoinClause)
    WHERE s.sticker_id = ?
    LIMIT 1
    """
    private static let sqlQueryRecentUsedStickers = """
    \(sqlQueryColumns)
    \(relationShipJoinClause)
    \(albumJoinClause)
    WHERE s.last_used_at IS NOT NULL
    GROUP BY s.sticker_id
    ORDER BY s.last_used_at DESC
    LIMIT ?
    """
    
    public static let shared = StickerDAO()
    
    public func isExist(stickerId: String) -> Bool {
        db.recordExists(in: Sticker.self, where: Sticker.column(of: .stickerId) == stickerId)
    }
    
    public func getSticker(albumId: String, name: String) -> StickerItem? {
        db.select(with: StickerDAO.sqlQuerySticker, arguments: [albumId, name])
    }
    
    public func getSticker(stickerId: String) -> StickerItem? {
        db.select(with: StickerDAO.sqlQueryStickerByStickerId, arguments: [stickerId])
    }
    
    public func getStickers(albumId: String) -> [StickerItem] {
        db.select(with: StickerDAO.sqlQueryStickersByAlbum, arguments: [albumId])
    }
    
    public func getStickers(albumIds: [String]) -> [String: [StickerItem]] {
        guard !albumIds.isEmpty else {
            return [:]
        }
        let keys = albumIds.map { _ in "?" }.joined(separator: ",")
        let sql = """
        \(Self.sqlQueryColumns)
        \(Self.relationShipJoinClause) AND sa.album_id in (\(keys))
        \(Self.albumJoinClause)
        ORDER BY sa.created_at DESC
        """
        let stickers: [StickerItem] = db.select(with: sql, arguments: StatementArguments(albumIds))
        var stickerMap = [String: [StickerItem]]()
        for sticker in stickers {
            guard let albumId = sticker.albumId else {
                continue
            }
            if let stickers = stickerMap[albumId] {
                stickerMap[albumId] = stickers + [sticker]
            } else {
                stickerMap[albumId] = [sticker]
            }
        }
        return stickerMap
    }
    
    public func getFavoriteStickers() -> [StickerItem] {
        db.select(with: StickerDAO.sqlQueryFavoriteStickers)
    }
    
    public func isFavoriteSticker(stickerId: String) -> Bool {
        let sql = """
            SELECT 1
            FROM stickers s
            \(Self.relationShipJoinClause)
            \(Self.albumJoinClause)
            WHERE s.sticker_id = ? AND a.category = 'PERSONAL'
        """
        let value: Int64 = db.select(with: sql, arguments: [stickerId]) ?? 0
        return value > 0
    }
    
    public func recentUsedStickers(limit: Int) -> [StickerItem] {
        db.select(with: StickerDAO.sqlQueryRecentUsedStickers, arguments: [limit])
    }
    
    public func insertOrUpdateSticker(sticker: StickerResponse) -> StickerItem? {
        var stickerItem: StickerItem?
        db.write { (db) in
            try insertOrUpdateSticker(into: db, with: sticker)
            db.afterNextTransaction { (db) in
                stickerItem = try? StickerItem.fetchOne(db,
                                                        sql: StickerDAO.sqlQueryStickerByStickerId,
                                                        arguments: [sticker.stickerId])
            }
        }
        return stickerItem
    }
    
    public func insertOrUpdateStickers(stickers: [StickerResponse], albumId: String) -> [StickerItem] {
        var stickerItems: [StickerItem] = []
        db.write { (db) in
            for response in stickers {
                let relationship = StickerRelationship(albumId: albumId, stickerId: response.stickerId, createdAt: response.createdAt)
                try relationship.save(db)
                try insertOrUpdateSticker(into: db, with: response)
            }
            db.afterNextTransaction { (db) in
                NotificationCenter.default.post(onMainThread: Self.favoriteStickersDidChangeNotification, object: self)
                stickerItems = (try? StickerItem.fetchAll(db,
                                                          sql: StickerDAO.sqlQueryStickersByAlbum,
                                                          arguments: [albumId])) ?? []
            }
        }
        return stickerItems
    }
    
    public func insertOrUpdateFavoriteSticker(sticker: StickerResponse) {
        if let albumId = AlbumDAO.shared.getPersonalAlbum()?.albumId {
            insertOrUpdateStickers(stickers: [sticker], albumId: albumId)
        } else if let albumId = sticker.albumId {
            switch StickerAPI.album(albumId: albumId) {
            case let .success(album):
                AlbumDAO.shared.insertOrUpdateAblum(album: album)
                insertOrUpdateStickers(stickers: [sticker], albumId: albumId)
            case .failure:
                ConcurrentJobQueue.shared.addJob(job: RefreshAlbumJob())
            }
        } else {
            ConcurrentJobQueue.shared.addJob(job: RefreshAlbumJob())
        }
    }
    
    public func updateUsedAt(stickerId: String, usedAt: String) {
        db.update(Sticker.self,
                  assignments: [Sticker.column(of: .lastUseAt).set(to: usedAt)],
                  where: Sticker.column(of: .stickerId) == stickerId)
    }
    
    public func stickers(limit: Int, offset: Int) -> [Sticker] {
        let sql = "SELECT * FROM stickers ORDER BY rowid LIMIT ? OFFSET ?"
        return db.select(with: sql, arguments: [limit, offset])
    }
    
    public func stickersCount() -> Int {
        let count: Int? = db.select(with: "SELECT COUNT(*) FROM stickers")
        return count ?? 0
    }
    
    public func inser(sticker: Sticker) {
        db.save(sticker)
    }
    
    private func insertOrUpdateSticker(into db: GRDB.Database, with response: StickerResponse) throws {
        let sticker = Sticker(response: response)
        if try sticker.exists(db) {
            let assignments = [
                Sticker.column(of: .stickerId).set(to: response.stickerId),
                Sticker.column(of: .name).set(to: response.name),
                Sticker.column(of: .assetUrl).set(to: response.assetUrl),
                Sticker.column(of: .assetType).set(to: response.assetType),
                Sticker.column(of: .assetWidth).set(to: response.assetWidth),
                Sticker.column(of: .assetHeight).set(to: response.assetHeight),
                Sticker.column(of: .albumId).set(to: response.albumId)
            ]
            try Sticker
                .filter(Sticker.column(of: .stickerId) == response.stickerId)
                .updateAll(db, assignments)
        } else {
            try sticker.save(db)
        }
    }
    
}
