import Foundation
import WCDBSwift

public class AlbumDAO {
    
    private static let sqlQueryAlbumByStickerId = """
    SELECT a.album_id, a.name, a.icon_url, a.created_at, a.update_at, a.user_id, a.category, a.description FROM albums a
    INNER JOIN sticker_relationships sa ON sa.album_id = a.album_id AND sa.sticker_id = ?
    LIMIT 1
    """
    
    static let shared = AlbumDAO()
    
    func getAlbum(stickerId: String) -> Album? {
        return MixinDatabase.shared.getCodables(on: Album.Properties.all, sql: AlbumDAO.sqlQueryAlbumByStickerId, values: [stickerId]).first
    }
    
    func getSelfAlbum() -> Album? {
        return MixinDatabase.shared.getCodable(condition: Album.Properties.category == AlbumCategory.PERSONAL.rawValue)
    }
    
    func getSelfAlbumId() -> String? {
        return getSelfAlbum()?.albumId
    }
    
    func getAlbums() -> [Album] {
        return MixinDatabase.shared.getCodables(condition: Album.Properties.category != AlbumCategory.PERSONAL.rawValue, orderBy: [Album.Properties.updatedAt.asOrder(by: .descending)])
    }
    
    func getAblumsUpdateAt() -> [String: String] {
        return MixinDatabase.shared.getDictionary(key: Album.Properties.albumId.asColumnResult(), value: Album.Properties.updatedAt.asColumnResult(), tableName: Album.tableName)
    }
    
    func insertOrUpdateAblum(album: Album) {
        MixinDatabase.shared.insertOrReplace(objects: [album])
    }
        
}
