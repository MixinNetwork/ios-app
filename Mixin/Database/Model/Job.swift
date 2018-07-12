import Foundation
import WCDBSwift

struct Job: BaseCodable {

    static var tableName: String = "jobs"
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    var orderId: Int?
    let jobId: String
    let priority: Int
    let action: String

    let userId: String?
    let blazeMessage: Data?
    let conversationId: String?
    let resendMessageId: String?
    var runCount: Int = 0

    var isAutoIncrement = true

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Job
        case orderId
        case jobId = "job_id"
        case priority
        case blazeMessage = "blaze_message"
        case action
        case conversationId = "conversation_id"
        case userId = "user_id"
        case resendMessageId = "resend_message_id"
        case runCount = "run_count"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                orderId: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_index_id": IndexBinding(isUnique: true, indexesBy: jobId)
            ]
        }
    }

    init(jobId: String, action: JobAction, userId: String? = nil, conversationId: String? = nil, resendMessageId: String? = nil, blazeMessage: BlazeMessage? = nil) {
        self.jobId = jobId
        switch action {
        case .RESEND_MESSAGE:
            self.priority = JobPriority.RESEND_MESSAGE.rawValue
        case .SEND_DELIVERED_ACK_MESSAGE:
            self.priority = JobPriority.SEND_DELIVERED_ACK_MESSAGE.rawValue
        case .SEND_ACK_MESSAGE:
            self.priority = JobPriority.SEND_ACK_MESSAGE.rawValue
        default:
            self.priority = JobPriority.SEND_MESSAGE.rawValue
        }
        self.action = action.rawValue
        self.userId = userId
        self.conversationId = conversationId
        self.resendMessageId = resendMessageId
        if let message = blazeMessage {
            self.blazeMessage = try! Job.encoder.encode(message)
        } else {
            self.blazeMessage = nil
        }
    }
}


extension Job {

    func toBlazeMessage() -> BlazeMessage {
        return try! Job.decoder.decode(BlazeMessage.self, from: blazeMessage!)
    }

}

extension Job {

    init(message: Message) {
        let blazeParam = BlazeMessageParam(conversationId: message.conversationId, recipientId: nil, category: message.category, data: nil, offset: nil, status: MessageStatus.SENT.rawValue, messageId: message.messageId, quoteMessageId: nil, keys: nil, recipients: nil, messages: nil)
        let blazeMessage = BlazeMessage(params: blazeParam, action: BlazeMessageAction.createMessage.rawValue)
        self.init(jobId: blazeMessage.id, action: .SEND_MESSAGE, blazeMessage: blazeMessage)
    }
}


enum JobPriority: Int {
    case SEND_MESSAGE = 18
    case RESEND_MESSAGE = 15
    case SEND_DELIVERED_ACK_MESSAGE = 7
    case SEND_ACK_MESSAGE = 5
}

enum JobAction: String {
    case REQUEST_RESEND_KEY
    case REQUEST_RESEND_MESSAGES
    case RESEND_MESSAGE
    case RESEND_KEY
    case SEND_NO_KEY
    case SEND_KEY
    case SEND_MESSAGE
    case SEND_ACK_MESSAGE
    case SEND_DELIVERED_ACK_MESSAGE
}


