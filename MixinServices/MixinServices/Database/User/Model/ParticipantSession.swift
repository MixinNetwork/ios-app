import Foundation
import GRDB

public enum SenderKeyStatus: Int {
    case UNKNOWN = 0
    case SENT = 1
}

public struct ParticipantSession {
    
    public let conversationId: String
    public let userId: String
    public let sessionId: String
    public let sentToServer: Int?
    public let createdAt: String
    public let publicKey: String?
    
    public init(conversationId: String, userId: String, sessionId: String, sentToServer: Int?, createdAt: String, publicKey: String?) {
        self.conversationId = conversationId
        self.userId = userId
        self.sessionId = sessionId
        self.sentToServer = sentToServer
        self.createdAt = createdAt
        self.publicKey = publicKey
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try container.decode(String.self, forKey: .conversationId)
        userId = try container.decode(String.self, forKey: .userId)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        sentToServer = try container.decodeIfPresent(Int.self, forKey: .sentToServer)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        publicKey = try container.decodeIfPresent(String.self, forKey: .publicKey)
    }
    
}

extension ParticipantSession {
    
    public struct Sent: Codable, MixinFetchableRecord {
        
        public enum CodingKeys: String, CodingKey {
            case conversationId = "conversation_id"
            case userId = "user_id"
            case sessionId = "session_id"
            case sentToServer = "sent_to_server"
        }
        
        public let conversationId: String
        public let userId: String
        public let sessionId: String
        public let sentToServer: Int?
        
        public init(conversationId: String, userId: String, sessionId: String, sentToServer: Int?) {
            self.conversationId = conversationId
            self.userId = userId
            self.sessionId = sessionId
            self.sentToServer = sentToServer
        }
        
        public var participantSession: ParticipantSession {
            ParticipantSession(conversationId: conversationId,
                               userId: userId,
                               sessionId: sessionId,
                               sentToServer: sentToServer,
                               createdAt: Date().toUTCString(),
                               publicKey: nil)
        }
        
    }
    
    public struct Key: Codable, MixinFetchableRecord {
        
        public enum CodingKeys: String, CodingKey {
            case conversationId = "conversation_id"
            case userId = "user_id"
            case sessionId = "session_id"
            case publicKey = "public_key"
        }
        
        public let conversationId: String
        public let userId: String
        public let sessionId: String
        public let publicKey: String?
        
        public init(conversationId: String, userId: String, sessionId: String, publicKey: String?) {
            self.conversationId = conversationId
            self.userId = userId
            self.sessionId = sessionId
            self.publicKey = publicKey
        }
        
    }
    
}

extension ParticipantSession: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case sessionId = "session_id"
        case sentToServer = "sent_to_server"
        case createdAt = "created_at"
        case publicKey = "public_key"
    }
    
}

extension ParticipantSession: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "participant_session"
    
}

extension ParticipantSession {
    
    public var uniqueIdentifier: String {
        return "\(userId)\(sessionId)"
    }
    
}
