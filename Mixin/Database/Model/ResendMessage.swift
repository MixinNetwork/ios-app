import Foundation
import WCDBSwift

struct ResendMessage: BaseCodable {

    static var tableName: String = "resend_messages"

    let messageId: String
    let userId: String
    let status: Int

    enum CodingKeys: String, CodingTableKey {
        typealias Root = ResendMessage
        case messageId = "message_id"
        case userId = "user_id"
        case status

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: messageId, userId)
            ]
        }
    }
}
