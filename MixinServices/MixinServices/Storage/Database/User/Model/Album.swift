import Foundation
import GRDB

public enum AlbumCategory: String, Codable {
    case PERSONAL
    case SYSTEM
}

public struct Album {
    
    public let albumId: String
    public let name: String
    public let iconUrl: String
    public let createdAt: String
    public let updatedAt: String
    public let userId: String
    public let category: String
    public let description: String
    
}

extension Album: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case albumId = "album_id"
        case name
        case iconUrl = "icon_url"
        case createdAt = "created_at"
        case updatedAt = "update_at"
        case userId = "user_id"
        case category
        case description
    }
    
}

extension Album: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "albums"
    
}
