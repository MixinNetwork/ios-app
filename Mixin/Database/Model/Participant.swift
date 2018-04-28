import WCDBSwift

struct Participant: BaseCodable {

    static var tableName: String = "participants"

    let conversationId: String
    let userId: String
    let role: String
    let status: Int
    let createdAt: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Participant
        case conversationId = "conversation_id"
        case userId = "user_id"
        case role
        case status
        case createdAt = "created_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            let foreignKey = ForeignKey(withForeignTable: Conversation.tableName, and: conversationId).onDelete(.cascade)
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: conversationId, userId),
                "_foreign_key_constraint": ForeignKeyBinding(conversationId, foreignKey: foreignKey)
            ]
        }
    }
}

enum ParticipantRole: String {
    case OWNER
    case ADMIN
}

enum ParticipantAction: String {
    case ADD
    case REMOVE
    case JOIN
    case EXIT
    case ROLE
}

enum ParticipantStatus: Int {
    case START = 0
    case SUCCESS = 1
    case ERROR = 2
}
