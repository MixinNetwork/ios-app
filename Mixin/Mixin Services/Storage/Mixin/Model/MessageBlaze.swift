import Foundation
import WCDBSwift

struct MessageBlaze: BaseCodable {

    static var tableName: String = "messages_blaze"

    public let messageId: String
    public let conversationId: String
    public let message: Data
    public let createdAt: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = MessageBlaze
        case messageId = "_id"
        case conversationId = "conversation_id"
        case message
        case createdAt = "created_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                messageId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_index": IndexBinding(indexesBy: [createdAt]),
                "_conversation_indexs": IndexBinding(indexesBy: [conversationId, createdAt])
            ]
        }
    }

}
