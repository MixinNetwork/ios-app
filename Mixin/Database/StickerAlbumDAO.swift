import WCDBSwift

final class StickerAlbumDAO {

    static let shared = StickerAlbumDAO()
    
    func getAlbums() -> [StickerAlbum] {
        return MixinDatabase.shared.getCodables(condition: StickerAlbum.Properties.category != AlbumCategory.PERSONAL.rawValue, orderBy: [StickerAlbum.Properties.updateAt.asOrder(by: .descending)], inTransaction: false)
    }

    func getAblumsUpdateAt() -> [String: String] {
        return MixinDatabase.shared.getDictionary(key: StickerAlbum.Properties.albumId.asColumnResult(), value: StickerAlbum.Properties.updateAt.asColumnResult(), tableName: StickerAlbum.tableName)
    }

    func insertOrUpdateAblum(album: StickerAlbum) {
        MixinDatabase.shared.insertOrReplace(objects: [album])
    }

}
