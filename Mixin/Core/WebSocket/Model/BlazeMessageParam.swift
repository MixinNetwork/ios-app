import Foundation

struct BlazeMessageParam: Codable {

    var conversationId: String? = nil
    var recipientId: String? = nil
    var category: String? = nil
    var data: String? = nil
    var offset: String? = nil

    var status: String? = nil
    var messageId: String? = nil
    var quoteMessageId: String? = nil

    var keys: SignalKeyRequest? = nil
    var recipients: [String]? = nil
    var messages: [BlazeSignalMessage]? = nil

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case recipientId = "recipient_id"
        case category
        case data
        case offset
        case status
        case messageId = "message_id"
        case quoteMessageId = "quote_message_id"

        case keys
        case recipients
        case messages
    }
}

extension BlazeMessageParam {

    init(messageId: String, status: String) {
        self.messageId = messageId
        self.status = status
    }

    init(offset: String) {
        self.offset = offset
    }

    init(conversationId: String, recipientId: String, cipherText: String) {
        self.messageId = UUID().uuidString.lowercased()
        self.status = MessageStatus.SENT.rawValue
        self.conversationId = conversationId
        self.recipientId = recipientId
        self.data = cipherText
        self.category = MessageCategory.SIGNAL_KEY.rawValue
    }

    init(consumeSignalKeys recipients: [String]) {
        self.recipients = recipients
    }

    init(syncSignalKeys keys: SignalKeyRequest) {
        self.keys = keys
    }

    init(conversationId: String, messages: [BlazeSignalMessage]) {
        self.conversationId = conversationId
        self.messages = messages
    }
}
