import Foundation
import WCDBSwift

struct MessageHistory: BaseCodable {

    static var tableName: String = "messages_history"

    public let messageId: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = MessageHistory
        case messageId = "message_id"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                messageId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
}
