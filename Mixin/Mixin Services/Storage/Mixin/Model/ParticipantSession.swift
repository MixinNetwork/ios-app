import WCDBSwift

public struct ParticipantSession: BaseCodable {
    
    public static let tableName: String = "participant_session"
    
    public let conversationId: String
    public let userId: String
    public let sessionId: String
    public let sentToServer: Int?
    public let createdAt: String
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = ParticipantSession
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: conversationId, userId, sessionId)
            ]
        }
        
        case conversationId = "conversation_id"
        case userId = "user_id"
        case sessionId = "session_id"
        case sentToServer = "sent_to_server"
        case createdAt = "created_at"
        
    }
    
    public init(conversationId: String, userId: String, sessionId: String, sentToServer: Int?, createdAt: String) {
        self.conversationId = conversationId
        self.userId = userId
        self.sessionId = sessionId
        self.sentToServer = sentToServer
        self.createdAt = createdAt
    }
    
}

extension ParticipantSession {
    
    public var uniqueIdentifier: String {
        return "\(userId)\(sessionId)"
    }
    
}

public enum SenderKeyStatus: Int {
    case UNKNOWN = 0
    case SENT = 1
}

