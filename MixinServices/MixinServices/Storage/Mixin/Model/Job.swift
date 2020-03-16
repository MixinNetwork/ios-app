import Foundation
import WCDBSwift

internal struct Job: BaseCodable {
    
    static let tableName: String = "jobs"
    
    var orderId: Int?
    let jobId: String
    let priority: Int
    let action: String
    let category: String
    
    let userId: String?
    let blazeMessage: Data?
    let conversationId: String?
    let resendMessageId: String?
    var messageId: String?
    var status: String?
    var sessionId: String?

    var isAutoIncrement = true
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = Job
        case orderId
        case jobId = "job_id"
        case priority
        case blazeMessage = "blaze_message"
        case action
        case category
        case conversationId = "conversation_id"
        case userId = "user_id"
        case resendMessageId = "resend_message_id"
        case messageId = "message_id"
        case status
        case sessionId = "session_id"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                orderId: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_index_id": IndexBinding(isUnique: true, indexesBy: jobId),
                "_next_indexs": IndexBinding(indexesBy: [category, priority.asIndex(orderBy: .descending), orderId.asIndex(orderBy: .ascending)]),
            ]
        }
    }
    
    init(jobId: String, action: JobAction, userId: String? = nil, conversationId: String? = nil, resendMessageId: String? = nil, sessionId: String? = nil, blazeMessage: BlazeMessage? = nil) {
        self.jobId = jobId
        switch action {
        case .RESEND_MESSAGE:
            self.category = JobCategory.WebSocket.rawValue
            self.priority = JobPriority.RESEND_MESSAGE.rawValue
        case .SEND_DELIVERED_ACK_MESSAGE:
            self.category = JobCategory.Http.rawValue
            self.priority = JobPriority.SEND_DELIVERED_ACK_MESSAGE.rawValue
        case .SEND_ACK_MESSAGE, .SEND_ACK_MESSAGES:
            self.category = JobCategory.Http.rawValue
            self.priority = JobPriority.SEND_ACK_MESSAGE.rawValue
        case .SEND_SESSION_MESSAGE, .SEND_SESSION_MESSAGES:
            self.category = JobCategory.WebSocket.rawValue
            self.priority = JobPriority.SEND_ACK_MESSAGE.rawValue
        default:
            self.category = JobCategory.WebSocket.rawValue
            self.priority = JobPriority.SEND_MESSAGE.rawValue
        }
        self.action = action.rawValue
        self.userId = userId
        self.conversationId = conversationId
        self.resendMessageId = resendMessageId
        if let message = blazeMessage {
            self.blazeMessage = try! JSONEncoder.default.encode(message)
        } else {
            self.blazeMessage = nil
        }
        self.messageId = nil
        self.status = nil
        self.sessionId = sessionId
    }
}


extension Job {
    
    func toBlazeMessage() -> BlazeMessage {
        return try! JSONDecoder.default.decode(BlazeMessage.self, from: blazeMessage!)
    }
    
}

extension Job {
    
    init(message: Message, representativeId: String? = nil, data: String? = nil) {
        let param = BlazeMessageParam(conversationId: message.conversationId,
                                      category: message.category,
                                      data: data,
                                      status: MessageStatus.SENT.rawValue,
                                      messageId: message.messageId,
                                      representativeId: representativeId)
        let action = BlazeMessageAction.createMessage.rawValue
        let blazeMessage = BlazeMessage(params: param, action: action)
        self.init(jobId: blazeMessage.id, action: .SEND_MESSAGE, blazeMessage: blazeMessage)
    }
    
    init(webRTCMessage message: Message, recipientId: String) {
        let param = BlazeMessageParam(conversationId: message.conversationId,
                                      recipientId: recipientId,
                                      category: message.category,
                                      data: message.content?.base64Encoded(),
                                      messageId: message.messageId,
                                      quoteMessageId: message.quoteMessageId)
        let action = BlazeMessageAction.createCall.rawValue
        let blazeMessage = BlazeMessage(params: param, action: action)
        self.init(jobId: blazeMessage.id, action: .SEND_MESSAGE, blazeMessage: blazeMessage)
    }
    
    init(sessionRead conversationId: String, messageId: String, status: String = MessageStatus.READ.rawValue) {
        self.jobId = UUID().uuidString.lowercased()
        self.priority = JobPriority.SEND_ACK_MESSAGE.rawValue
        self.action = JobAction.SEND_SESSION_MESSAGE.rawValue
        self.userId = nil
        self.conversationId = conversationId
        self.resendMessageId = nil
        self.blazeMessage = nil
        self.messageId = messageId
        self.status = status
        self.sessionId = nil
        self.category = JobCategory.WebSocket.rawValue
    }

    init(attachmentMessage messageId: String, action: JobAction) {
        self.jobId = UUID().uuidString.lowercased()
        self.priority = JobPriority.SEND_ACK_MESSAGE.rawValue
        self.action = action.rawValue
        self.userId = nil
        self.conversationId = nil
        self.resendMessageId = nil
        self.blazeMessage = nil
        self.messageId = messageId
        self.status = nil
        self.sessionId = nil
        self.category = JobCategory.Task.rawValue
    }
}


enum JobPriority: Int {
    case SEND_MESSAGE = 18
    case RESEND_MESSAGE = 15
    case SEND_DELIVERED_ACK_MESSAGE = 7
    case SEND_ACK_MESSAGE = 5
}

public enum JobAction: String {
    case REQUEST_RESEND_KEY
    case REQUEST_RESEND_MESSAGES
    case RESEND_MESSAGE
    case RESEND_KEY
    case SEND_NO_KEY
    case SEND_MESSAGE
    case SEND_ACK_MESSAGE
    case SEND_ACK_MESSAGES
    case SEND_DELIVERED_ACK_MESSAGE

    case REFRESH_SESSION

    case SEND_SESSION_MESSAGE
    case SEND_SESSION_MESSAGES

    case RECOVER_ATTACHMENT
    case UPLOAD_ATTACHMENT
}

public enum JobCategory: String {
    case WebSocket
    case Http
    case Task
}
