import WCDBSwift

struct ParticipantSession: BaseCodable {

    static var tableName: String = "participant_session"

    public let conversationId: String
    public let userId: String
    public let sessionId: String
    public let sentToServer: Int?
    public let createdAt: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = ParticipantSession
        case conversationId = "conversation_id"
        case userId = "user_id"
        case sessionId = "session_id"
        case sentToServer = "sent_to_server"
        case createdAt = "created_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: conversationId, userId, sessionId)
            ]
        }
    }
}

extension ParticipantSession {

    public var uniqueIdentifier: String {
        return "\(userId)\(sessionId)"
    }

}

enum SenderKeyStatus: Int {
    case UNKNOWN = 0
    case SENT = 1
}

