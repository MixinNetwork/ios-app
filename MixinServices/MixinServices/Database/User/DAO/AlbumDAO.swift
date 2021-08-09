import Foundation
import GRDB

public final class AlbumDAO: UserDatabaseDAO {
    
    public static let shared = AlbumDAO()
    
    public func getAlbum(stickerId: String) -> Album? {
        let sql = """
            SELECT a.*
            FROM albums a
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
    
    public func getAlbums(with albumIds: [String]) -> [Album] {
        guard !albumIds.isEmpty else {
            return []
        }
        let keys = albumIds.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT a.*
            FROM albums a
            WHERE a.album_id in (\(keys))
        """
        let albums: [Album] = db.select(with: sql, arguments: StatementArguments(albumIds))
        let albumMap = albums.reduce(into: [String: Album]()) { $0[$1.albumId] = $1 }
        return albumIds.compactMap({ albumMap[$0] })
    }
    
    public func getAblumsUpdateAt() -> [String: String] {
        db.select(keyColumn: Album.column(of: .albumId),
                  valueColumn: Album.column(of: .updatedAt),
                  from: Album.self)
    }
    
    public func insertOrUpdateAblum(album: Album) {
        db.save(album)
    }
    
}
