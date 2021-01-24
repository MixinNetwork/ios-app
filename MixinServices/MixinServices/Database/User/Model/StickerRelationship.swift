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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        albumId = try container.decode(String.self, forKey: .albumId)
        stickerId = try container.decode(String.self, forKey: .stickerId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
    
}

extension StickerRelationship: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "sticker_relationships"
    
}
