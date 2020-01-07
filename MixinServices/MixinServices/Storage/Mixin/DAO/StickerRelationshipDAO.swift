import WCDBSwift

public final class StickerRelationshipDAO {
    
    public static let shared = StickerRelationshipDAO()
    
    public func removeStickers(albumId: String, stickerIds: [String]) {
        MixinDatabase.shared.delete(table: StickerRelationship.tableName, condition: StickerRelationship.Properties.albumId == albumId
            && StickerRelationship.Properties.stickerId.in(stickerIds))
        
        NotificationCenter.default.afterPostOnMain(name: .FavoriteStickersDidChange)
    }
    
}
