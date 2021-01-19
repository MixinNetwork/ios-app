import Foundation
import GRDB

public enum ParticipantRole: String {
    case OWNER
    case ADMIN
}

public enum ParticipantAction: String {
    case ADD
    case REMOVE
    case JOIN
    case EXIT
    case ROLE
}

public enum ParticipantStatus: Int {
    case START = 0
    case SUCCESS = 1
    case ERROR = 2
}

public struct Participant {
    
    public let conversationId: String
    public let userId: String
    public let role: String
    public let status: Int
    public let createdAt: String
    
}

extension Participant: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {

    public enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case role
        case status
        case createdAt = "created_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try container.decode(String.self, forKey: .conversationId)
        userId = try container.decode(String.self, forKey: .userId)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        status = try container.decodeIfPresent(Int.self, forKey: .status) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
    
}

extension Participant: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "participants"
    
}
