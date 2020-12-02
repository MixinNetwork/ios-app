import Foundation
import GRDB

public struct FavoriteApp {
    
    public let userId: String
    public let appId: String
    public let createdAt: String
    
}

extension FavoriteApp: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {

    public enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case appId = "app_id"
        case createdAt = "created_at"
    }
    
}

extension FavoriteApp: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "favorite_apps"
    
}
