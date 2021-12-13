import Foundation
import GRDB

public final class AlbumDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let albumId = "aid"
        public static let isAdded = "added"
    }
    
    public static let shared = AlbumDAO()
    
    public static let addedAlbumsDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.AlbumDAO.AddedAlbumsDidChange")
    public static let albumsOrderDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.AlbumDAO.AlbumsOrderDidChange")
    
    public func getAlbum(stickerId: String) -> Album? {
        let sql = """
            SELECT a.*
            FROM albums a
            INNER JOIN sticker_relationships sa ON sa.album_id = a.album_id AND sa.sticker_id = ?
            LIMIT 1
        """
        return db.select(with: sql, arguments: [stickerId])
    }
    
    public func getPersonalAlbum() -> Album? {
        db.select(where: Album.column(of: .category) == AlbumCategory.PERSONAL.rawValue)
    }
    
    public func getNonPersonalAlbums() -> [Album] {
        db.select(where: Album.column(of: .category) != AlbumCategory.PERSONAL.rawValue,
                  order: [Album.column(of: .updatedAt).desc])
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
    
    public func updateAlbum(with id: String, isAdded: Bool) {
        db.write { db in
            let orderedAt: Int
            if isAdded {
                let maxOrderedAt: Int? = try Album
                    .select(max(Album.column(of: .orderedAt)))
                    .fetchOne(db)
                if let maxOrderedAt = maxOrderedAt {
                    orderedAt = maxOrderedAt + 1
                } else {
                    orderedAt = 0
                }
            } else {
                orderedAt = 0
            }
            let assignments = [
                Album.column(of: .isAdded).set(to: isAdded),
                Album.column(of: .orderedAt).set(to: orderedAt)
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
            for (index, albumId) in albumdIds.reversed().enumerated() {
                try Album
                    .filter(Album.column(of: .albumId) == albumId)
                    .updateAll(db, [Album.column(of: .orderedAt).set(to: index)])
            }
            db.afterNextTransactionCommit { _ in
                NotificationCenter.default.post(onMainThread: AlbumDAO.albumsOrderDidChangeNotification,
                                                object: self)
            }
        }
    }
    
}
