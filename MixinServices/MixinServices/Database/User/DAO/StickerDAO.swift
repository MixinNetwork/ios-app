import GRDB

public final class StickerDAO: UserDatabaseDAO {
    
    public static let favoriteStickersDidChangeNotification = NSNotification.Name("one.mixin.services.StickerDAO.favoriteStickersDidChange")
    
    private static let sqlQueryColumns = """
    SELECT s.sticker_id, s.name, s.asset_url, s.asset_type, s.asset_width, s.asset_height, s.last_used_at, a.category
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
    
    public func getFavoriteStickers() -> [StickerItem] {
        db.select(with: StickerDAO.sqlQueryFavoriteStickers)
    }
    
    public func recentUsedStickers(limit: Int) -> [StickerItem] {
        db.select(with: StickerDAO.sqlQueryRecentUsedStickers, arguments: [limit])
    }
    
    public func insertOrUpdateSticker(sticker: StickerResponse) -> StickerItem? {
        var stickerItem: StickerItem?
        db.write { (db) in
            try insertOrUpdateSticker(into: db, with: sticker)
            db.afterNextTransactionCommit { (db) in
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
            db.afterNextTransactionCommit { (db) in
                NotificationCenter.default.post(onMainThread: Self.favoriteStickersDidChangeNotification, object: self)
                stickerItems = (try? StickerItem.fetchAll(db,
                                                          sql: StickerDAO.sqlQueryStickersByAlbum,
                                                          arguments: [albumId])) ?? []
            }
        }
        return stickerItems
    }
    
    public func insertOrUpdateFavoriteSticker(sticker: StickerResponse) {
        if let albumId = AlbumDAO.shared.getSelfAlbumId() {
            insertOrUpdateStickers(stickers: [sticker], albumId: albumId)
        } else {
            switch StickerAPI.albums() {
            case let .success(albums):
                for album in albums {
                    guard album.category == AlbumCategory.PERSONAL.rawValue else {
                        continue
                    }
                    AlbumDAO.shared.insertOrUpdateAblum(album: album)
                    insertOrUpdateStickers(stickers: [sticker], albumId: album.albumId)
                    break
                }
            case .failure:
                ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob(.albums))
            }
        }
    }
    
    public func updateUsedAt(stickerId: String, usedAt: String) {
        db.update(Sticker.self,
                  assignments: [Sticker.column(of: .lastUseAt).set(to: usedAt)],
                  where: Sticker.column(of: .stickerId) == stickerId)
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
            ]
            try Sticker
                .filter(Sticker.column(of: .stickerId) == response.stickerId)
                .updateAll(db, assignments)
        } else {
            try sticker.save(db)
        }
    }
    
}
