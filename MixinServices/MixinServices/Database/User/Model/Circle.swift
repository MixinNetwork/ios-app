import Foundation
import GRDB

public struct Circle {
    
    public let circleId: String
    public let name: String
    public let createdAt: String
    
    public init(circleId: String, name: String, createdAt: String) {
        self.circleId = circleId
        self.name = name
        self.createdAt = createdAt
    }
    
}

extension Circle: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case circleId = "circle_id"
        case name
        case createdAt = "created_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        circleId = try container.decode(String.self, forKey: .circleId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
    
}

extension Circle: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "circles"
    
}
