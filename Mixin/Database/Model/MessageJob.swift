import Foundation
import WCDBSwift

@available(*, deprecated, message: "Use Job instead.")
struct MessageJob: BaseCodable {

    static var tableName: String = "messages_job"

    let jobId: String
    let priority: Int
    let blazeMessage: Data
    let action: String
    let conversationId: String
    let userId: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = MessageJob
        case jobId = "job_id"
        case priority
        case blazeMessage = "blaze_message"
        case action
        case conversationId = "conversation_id"
        case userId = "user_id"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                jobId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
}

enum MessageJobAction: String {
    case RESEND_KEY
    case RESEND_KEY_MESSAGE
    case NO_KEY
    case RESEND_MESSAGES
    case SEND_KEY
}

