import Foundation
import GRDB

public struct Session {
    
    public let address: String
    public let device: Int32
    public let record: Data
    public let timestamp: TimeInterval
    
    public init(address: String, device: Int32, record: Data, timestamp: TimeInterval) {
        self.address = address
        self.device = device
        self.record = record
        self.timestamp = timestamp
    }
    
}

extension Session: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: CodingKey {
        case address
        case device
        case record
        case timestamp
    }
    
}

extension Session: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "sessions"
    
}
