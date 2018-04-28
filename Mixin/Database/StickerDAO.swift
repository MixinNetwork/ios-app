import WCDBSwift

final class StickerDAO {

    static let shared = StickerDAO()

    func isExist(albumId: String, name: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Sticker.self, condition: Sticker.Properties.albumId == albumId && Sticker.Properties.name == name, inTransaction: false)
    }

    func getStickers(albumId: String) -> [Sticker] {
        return MixinDatabase.shared.getCodables(condition: Sticker.Properties.albumId == albumId, inTransaction: false)
    }

    func recentUsedStickers(limit: Int) -> [Sticker] {
        return MixinDatabase.shared.getCodables(condition: Sticker.Properties.lastUseAt.isNotNull(), orderBy: [Sticker.Properties.lastUseAt.asOrder(by: .descending)], limit: limit, inTransaction: false)
    }

    func insertOrUpdateStickers(stickers: [Sticker]) {
        let lastUserAtProperty = Sticker.Properties.lastUseAt.asProperty()
        let propertyList = Sticker.Properties.all.filter { $0.name != lastUserAtProperty.name }
        MixinDatabase.shared.insertOrReplace(objects: stickers, on: propertyList)
    }

    func updateUsedAt(albumId: String, name: String, usedAt: String) {
        MixinDatabase.shared.update(maps: [(Sticker.Properties.lastUseAt, usedAt)], tableName: Sticker.tableName, condition: Sticker.Properties.albumId == albumId && Sticker.Properties.name == name)
    }
}
