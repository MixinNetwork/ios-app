import GRDB

public final class StickerRelationshipDAO: UserDatabaseDAO {
    
    public static let shared = StickerRelationshipDAO()
    
    public func removeStickers(albumId: String, stickerIds: [String]) {
        let condition = StickerRelationship.column(of: .albumId) == albumId
            && stickerIds.contains(StickerRelationship.column(of: .stickerId))
        db.delete(StickerRelationship.self, where: condition) { _ in
            NotificationCenter.default.post(onMainThread: StickerDAO.favoriteStickersDidChangeNotification, object: self)
        }
    }
    
}
