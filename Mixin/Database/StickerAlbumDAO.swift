import WCDBSwift

final class StickerAlbumDAO {

    static let shared = StickerAlbumDAO()

    func inserOrUpdate(albumId: String, stickers: [Sticker]) {
        MixinDatabase.shared.insertOrReplace(objects: stickers.map { StickerAlbum(albumId: albumId, stickerId: $0.stickerId) })
    }

    func removeStickers(albumId: String, stickerIds: [String]) {
        MixinDatabase.shared.delete(table: StickerAlbum.tableName, condition: StickerAlbum.Properties.albumId == albumId
            && StickerAlbum.Properties.stickerId.in(stickerIds))

        NotificationCenter.default.afterPostOnMain(name: .StickerDidChange)
    }

    func addStickers(albumId: String, stickerIds: [String]) {
        MixinDatabase.shared.insertOrReplace(objects: stickerIds.map { StickerAlbum(albumId: albumId, stickerId: $0) })
    }
}
