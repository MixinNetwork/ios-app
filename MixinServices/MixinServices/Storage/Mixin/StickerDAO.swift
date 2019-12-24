import WCDBSwift

public final class StickerDAO {
    
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
        return MixinDatabase.shared.isExist(type: Sticker.self, condition: Sticker.Properties.stickerId == stickerId)
    }
    
    public func getSticker(albumId: String, name: String) -> StickerItem? {
        return MixinDatabase.shared.getCodables(on: StickerItem.Properties.all, sql: StickerDAO.sqlQuerySticker, values: [albumId, name]).first
    }
    
    public func getSticker(stickerId: String) -> StickerItem? {
        return MixinDatabase.shared.getCodables(on: StickerItem.Properties.all, sql: StickerDAO.sqlQueryStickerByStickerId, values: [stickerId]).first
    }
    
    public func getStickers(albumId: String) -> [StickerItem] {
        return MixinDatabase.shared.getCodables(on: StickerItem.Properties.all, sql: StickerDAO.sqlQueryStickersByAlbum, values: [albumId])
    }
    
    public func getFavoriteStickers() -> [StickerItem] {
        return MixinDatabase.shared.getCodables(sql: StickerDAO.sqlQueryFavoriteStickers)
    }
    
    public func recentUsedStickers(limit: Int) -> [StickerItem] {
        return MixinDatabase.shared.getCodables(sql: StickerDAO.sqlQueryRecentUsedStickers, values: [limit])
    }
    
    public func insertOrUpdateSticker(sticker: StickerResponse) {
        let lastUserAtProperty = Sticker.Properties.lastUseAt.asProperty().name
        let propertyList = Sticker.Properties.all.filter { $0.name != lastUserAtProperty }
        
        MixinDatabase.shared.insertOrReplace(objects: [Sticker(response: sticker)], on: propertyList)
    }
    
    public func insertOrUpdateStickers(stickers: [StickerResponse], albumId: String) {
        let lastUserAtProperty = Sticker.Properties.lastUseAt.asProperty().name
        let propertyList = Sticker.Properties.all.filter { $0.name != lastUserAtProperty }
        
        MixinDatabase.shared.transaction { (database) in
            try database.insertOrReplace(objects: stickers.map { StickerRelationship(albumId: albumId, stickerId: $0.stickerId, createdAt: $0.createdAt) }, intoTable: StickerRelationship.tableName)
            try database.insertOrReplace(objects: stickers.map(Sticker.init), on: propertyList, intoTable: Sticker.tableName)
        }
        NotificationCenter.default.afterPostOnMain(name: .FavoriteStickersDidChange)
    }
    
    public func insertOrUpdateFavoriteSticker(sticker: StickerResponse) {
        if let albumId = AlbumDAO.shared.getSelfAlbumId() {
            insertOrUpdateStickers(stickers: [sticker], albumId: albumId)
        } else {
            switch StickerAPI.shared.albums() {
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
                ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob())
            }
        }
    }
    
    public func updateUsedAt(stickerId: String, usedAt: String) {
        MixinDatabase.shared.update(maps: [(Sticker.Properties.lastUseAt, usedAt)], tableName: Sticker.tableName, condition: Sticker.Properties.stickerId == stickerId)
    }
    
}
