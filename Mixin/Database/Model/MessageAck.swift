import Foundation
import WCDBSwift

@available(*, deprecated, message: "Use Job instead.")
struct MessageAck: BaseCodable {

    static var tableName: String = "messages_ack"

    let messageId: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = MessageAck
        case messageId = "message_id"
        case status
        case createdAt = "created_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                messageId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_index1": IndexBinding(indexesBy: [createdAt]),
                "_index2": IndexBinding(indexesBy: [status])
            ]
        }
    }

}
