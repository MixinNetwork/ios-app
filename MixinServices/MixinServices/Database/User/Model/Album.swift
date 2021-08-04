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
    public let banner: String?
    
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
        case banner
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        albumId = try container.decode(String.self, forKey: .albumId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        banner = try container.decodeIfPresent(String.self, forKey: .banner)
    }
    
}

extension Album: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "albums"
    
}
