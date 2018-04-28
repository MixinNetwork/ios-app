import Foundation
import WCDBSwift

struct SentSenderKey: BaseCodable {

    static var tableName: String = "sent_sender_keys"

    let conversationId: String
    let userId: String
    let sentToServer: Int

    enum CodingKeys: String, CodingTableKey {
        typealias Root = SentSenderKey
        case conversationId = "conversation_id"
        case userId = "user_id"
        case sentToServer = "sent_to_server"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: conversationId, userId)
            ]
        }
    }
}

enum SentSenderKeyStatus: Int {
    case UNKNOWN = 0
    case SENT = 1
}
