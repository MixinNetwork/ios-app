import WCDBSwift

struct SessionSync: TableCodable {

    static var tableName: String = "session_sync"

    let conversationId: String
    let createdAt: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = SessionSync
        case conversationId = "conversation_id"
        case createdAt = "created_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                conversationId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
}
