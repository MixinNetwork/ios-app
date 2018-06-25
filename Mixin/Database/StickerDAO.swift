import WCDBSwift

final class StickerDAO {

    static let shared = StickerDAO()

    func isExist(stickerId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Sticker.self, condition: Sticker.Properties.stickerId == stickerId, inTransaction: false)
    }

    func removeStickers(stickerIds: [String]) {
        MixinDatabase.shared.delete(table: Sticker.tableName, condition: Sticker.Properties.stickerId.in(stickerIds))

        NotificationCenter.default.afterPostOnMain(name: .StickerDidChange)
    }

    func getSticker(albumId: String, name: String) -> Sticker? {
        return MixinDatabase.shared.getCodable(condition: Sticker.Properties.albumId == albumId && Sticker.Properties.name == name)
    }

    func getStickers(albumId: String) -> [Sticker] {
        return MixinDatabase.shared.getCodables(condition: Sticker.Properties.albumId == albumId, inTransaction: false)
    }

    func getFavoriteStickers() -> [Sticker] {
        guard let albumnId = MixinDatabase.shared.scalar(on: StickerAlbum.Properties.albumId, fromTable: StickerAlbum.tableName, condition: StickerAlbum.Properties.category == AlbumCategory.PERSONAL.rawValue, inTransaction: false)?.stringValue, !albumnId.isEmpty else {
            return []
        }
        return getStickers(albumId: albumnId)
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

    func updateUsedAt(albumId: String, name: String, usedAt: String) {
        MixinDatabase.shared.update(maps: [(Sticker.Properties.lastUseAt, usedAt)], tableName: Sticker.tableName, condition: Sticker.Properties.albumId == albumId && Sticker.Properties.name == name)
    }
}
