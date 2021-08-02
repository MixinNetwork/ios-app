import Foundation
import GRDB

public final class AlbumDAO: UserDatabaseDAO {
    
    public static let shared = AlbumDAO()
    
    public func getAlbum(stickerId: String) -> Album? {
        let sql = """
            SELECT a.album_id, a.name, a.icon_url, a.created_at, a.update_at, a.user_id, a.category, a.description FROM albums a
            INNER JOIN sticker_relationships sa ON sa.album_id = a.album_id AND sa.sticker_id = ?
            LIMIT 1
        """
        return db.select(with: sql, arguments: [stickerId])
    }
    
    public func getSelfAlbum() -> Album? {
        db.select(where: Album.column(of: .category) == AlbumCategory.PERSONAL.rawValue)
    }
    
    public func getSelfAlbumId() -> String? {
        getSelfAlbum()?.albumId
    }
    
    public func getAlbums() -> [Album] {
        db.select(where: Album.column(of: .category) != AlbumCategory.PERSONAL.rawValue,
                  order: [Album.column(of: .updatedAt).desc])
    }
    
    public func getAblumsUpdateAt() -> [String: String] {
        db.select(keyColumn: Album.column(of: .albumId),
                  valueColumn: Album.column(of: .updatedAt),
                  from: Album.self)
    }
    
    public func insertOrUpdateAblum(album: Album) {
        db.save(album)
    }
    
    public func deleteAlbum(albumId: String) {
        db.delete(User.self, where: Album.column(of: .albumId) == albumId)
    }
    
}
