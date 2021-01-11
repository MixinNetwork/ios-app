import Foundation
import GRDB

public struct StickerRelationship {
    
    public let albumId: String
    public let stickerId: String
    public let createdAt: String
    
}

extension StickerRelationship: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {

    public enum CodingKeys: String, CodingKey {
        case albumId = "album_id"
        case stickerId = "sticker_id"
        case createdAt = "created_at"
    }
    
}

extension StickerRelationship: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "sticker_relationships"
    
}
