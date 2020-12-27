import GRDB

public final class StickerRelationshipDAO: UserDatabaseDAO {
    
    public static let shared = StickerRelationshipDAO()
    
    public static let favoriteStickersDidChangeNotification = NSNotification.Name("one.mixin.services.StickerRelationshipDAO.favoriteStickersDidChange")
    
    public func removeStickers(albumId: String, stickerIds: [String]) {
        let condition = StickerRelationship.column(of: .albumId) == albumId
            && stickerIds.contains(StickerRelationship.column(of: .stickerId))
        db.delete(StickerRelationship.self, where: condition) { _ in
            NotificationCenter.default.post(onMainThread: Self.favoriteStickersDidChangeNotification, object: self)
        }
    }
    
}
