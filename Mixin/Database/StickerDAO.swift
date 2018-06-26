import WCDBSwift

final class StickerDAO {

    private static let sqlQueryColumns = """
    SELECT s.sticker_id, s.name, s.asset_url, s.asset_type, s.asset_width, s.asset_height, s.last_used_at FROM stickers s
    """
    private static let sqlQuerySticker = """
    \(sqlQueryColumns)
    INNER JOIN sticker_albums sa ON sa.sticker_id = s.sticker_id AND sa.album_id = ?
    WHERE s.name = ?
    LIMIT 1
    """
    private static let sqlQueryStickersByAlbum = """
    \(sqlQueryColumns)
    INNER JOIN sticker_albums sa ON sa.sticker_id = s.sticker_id AND sa.album_id = ?
    """
    private static let sqlQueryFavoriteStickers = """
    \(sqlQueryColumns)
    INNER JOIN sticker_albums sa ON sa.sticker_id = s.sticker_id
    INNER JOIN albums a ON a.album_id = sa.album_id AND a.category = 'PERSONAL'
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

    func insertOrUpdateStickers(stickers: [Sticker]) {
        let lastUserAtProperty = Sticker.Properties.lastUseAt.asProperty()
        let propertyList = Sticker.Properties.all.filter { $0.name != lastUserAtProperty.name }
        MixinDatabase.shared.insertOrReplace(objects: stickers, on: propertyList)
        NotificationCenter.default.afterPostOnMain(name: .StickerDidChange)
    }

    func updateUsedAt(stickerId: String, usedAt: String) {
        MixinDatabase.shared.update(maps: [(Sticker.Properties.lastUseAt, usedAt)], tableName: Sticker.tableName, condition: Sticker.Properties.stickerId == stickerId)
    }
}
