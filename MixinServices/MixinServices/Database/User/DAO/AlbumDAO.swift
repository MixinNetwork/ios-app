import Foundation
import GRDB

public final class AlbumDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let albumId = "aid"
        public static let isAdded = "added"
    }
    
    public static let shared = AlbumDAO()
    
    public static let addedAlbumsDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.AlbumDAO.addedAlbumsDidChangeNotification")
    public static let albumsOrderDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.AlbumDAO.albumsOrderDidChangeNotification")
    
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
    
    public func getAddedAlbums() -> [Album] {
        let condition: SQLSpecificExpressible = Album.column(of: .isAdded) == true
            && Album.column(of: .category) != AlbumCategory.PERSONAL.rawValue
        return db.select(where: condition,
                         order: [Album.column(of: .orderedAt).desc])
    }
    
    public func insertOrUpdateAblum(album: Album) {
        db.save(album)
    }
    
    public func updateAlbumAddedStatus(isAdded: Bool, forAlbumWithId id: String) {
        db.write { db in
            let assignments = [
                Album.column(of: .isAdded).set(to: isAdded),
                Album.column(of: .orderedAt).set(to: isAdded ? Date().toUTCString() : "0")
            ]
            try Album
                .filter(Album.column(of: .albumId) == id)
                .updateAll(db, assignments)
            db.afterNextTransactionCommit { db in
                let userInfo: [String: Any] = [
                    AlbumDAO.UserInfoKey.albumId: id,
                    AlbumDAO.UserInfoKey.isAdded: isAdded
                ]
                NotificationCenter.default.post(onMainThread: AlbumDAO.addedAlbumsDidChangeNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
    }
    
    public func updateAlbumsOrder(albumdIds: [String]) {
        db.write { db in
            let now = Date()
            for (index, albumId) in albumdIds.reversed().enumerated() {
                let orderedAt = now.addingTimeInterval(Double(index) / millisecondsPerSecond).toUTCString()
                try Album
                    .filter(Album.column(of: .albumId) == albumId)
                    .updateAll(db, [Album.column(of: .orderedAt).set(to: orderedAt)])
            }
            db.afterNextTransactionCommit { _ in
                NotificationCenter.default.post(onMainThread: AlbumDAO.albumsOrderDidChangeNotification,
                                                object: self)
            }
        }
    }
    
}
