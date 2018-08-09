import WCDBSwift

final class StickerDAO {

    private static let sqlQueryColumns = """
    SELECT s.sticker_id, s.name, s.asset_url, s.asset_type, s.asset_width, s.asset_height, s.last_used_at FROM stickers s
    """
    private static let sqlQuerySticker = """
    \(sqlQueryColumns)
    INNER JOIN sticker_relationships sa ON sa.sticker_id = s.sticker_id AND sa.album_id = ?
    WHERE s.name = ?
    LIMIT 1
    """
    private static let sqlQueryStickersByAlbum = """
    \(sqlQueryColumns)
    INNER JOIN sticker_relationships sa ON sa.sticker_id = s.sticker_id AND sa.album_id = ?
    ORDER BY sa.created_at ASC
    """
    private static let sqlQueryFavoriteStickers = """
    \(sqlQueryColumns)
    INNER JOIN sticker_relationships sa ON sa.sticker_id = s.sticker_id
    INNER JOIN albums a ON a.album_id = sa.album_id AND a.category = 'PERSONAL'
    ORDER BY sa.created_at ASC
    """

    static let shared = StickerDAO()

    func isExist(stickerId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Sticker.self, condition: Sticker.Properties.stickerId == stickerId, inTransaction: false)
    }

    func getSticker(albumId: String, name: String) -> Sticker? {
        return MixinDatabase.shared.getCodables(on: Sticker.Properties.all, sql: StickerDAO.sqlQuerySticker, values: [albumId, name], inTransaction: false).first
    }

    func getSticker(stickerId: String) -> Sticker? {
        return MixinDatabase.shared.getCodable(condition: Sticker.Properties.stickerId == stickerId)
    }

    func getStickers(albumId: String) -> [Sticker] {
        return MixinDatabase.shared.getCodables(on: Sticker.Properties.all, sql: StickerDAO.sqlQueryStickersByAlbum, values: [albumId], inTransaction: false)
    }

    func getFavoriteStickers() -> [Sticker] {
        return MixinDatabase.shared.getCodables(sql: StickerDAO.sqlQueryFavoriteStickers)
    }

    func recentUsedStickers(limit: Int) -> [Sticker] {
        return MixinDatabase.shared.getCodables(condition: Sticker.Properties.lastUseAt.isNotNull(), orderBy: [Sticker.Properties.lastUseAt.asOrder(by: .descending)], limit: limit, inTransaction: false)
    }

    func insertOrUpdateSticker(sticker: StickerResponse) {
        let lastUserAtProperty = Sticker.Properties.lastUseAt.asProperty().name
        let propertyList = Sticker.Properties.all.filter { $0.name != lastUserAtProperty }

        MixinDatabase.shared.transaction { (database) in
            try database.insertOrReplace(objects: Sticker.createSticker(from: sticker), on: propertyList, intoTable: Sticker.tableName)
        }
    }

    func insertOrUpdateStickers(stickers: [StickerResponse], albumId: String) {
        let lastUserAtProperty = Sticker.Properties.lastUseAt.asProperty().name
        let propertyList = Sticker.Properties.all.filter { $0.name != lastUserAtProperty }

        MixinDatabase.shared.transaction { (database) in
            try database.insertOrReplace(objects: stickers.map { StickerRelationship(albumId: albumId, stickerId: $0.stickerId, createdAt: $0.createdAt) }, intoTable: StickerRelationship.tableName)
            try database.insertOrReplace(objects: stickers.map { Sticker.createSticker(from: $0) }, on: propertyList, intoTable: Sticker.tableName)
            NotificationCenter.default.afterPostOnMain(name: .StickerDidChange)
        }
    }

    func insertOrUpdateFavoriteSticker(sticker: StickerResponse) {
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

    func updateUsedAt(stickerId: String, usedAt: String) {
        MixinDatabase.shared.update(maps: [(Sticker.Properties.lastUseAt, usedAt)], tableName: Sticker.tableName, condition: Sticker.Properties.stickerId == stickerId)
    }
}
