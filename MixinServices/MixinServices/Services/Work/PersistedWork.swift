import Foundation
import GRDB

public struct PersistedWork: Codable, DatabaseColumnConvertible, PersistableRecord, MixinFetchableRecord {
    
    public struct Priority: RawRepresentable, Codable {
        
        public static let high      = Priority(rawValue: 90)
        public static let medium    = Priority(rawValue: 50)
        public static let low       = Priority(rawValue: 10)
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
    }
    
    public enum CodingKeys: CodingKey {
        case id
        case type
        case context
        case priority
    }
    
    public static let databaseTableName = "works"
    
    public let id: String
    public let type: String
    public let context: Data?
    public let priority: Priority
    
    public init(id: String, type: String, context: Data?, priority: Priority) {
        self.id = id
        self.type = type
        self.context = context
        self.priority = priority
    }
    
}
