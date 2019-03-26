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
    var recipients: [BlazeSessionMessageParam]? = nil
    var messages: [TransferMessage]? = nil

    var sessionId: String? = nil
    var primitiveId: String? = nil
    var primitiveMessageId: String? = nil

    var representativeId: String? = nil

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

        case sessionId = "session_id"
        case primitiveId = "primitive_id"
        case primitiveMessageId = "primitive_message_id"

        case representativeId = "representative_id"
    }
}

extension BlazeMessageParam {

    init(messageId: String, status: String) {
        self.messageId = messageId
        self.status = status
    }
    
    init(conversationId: String, recipientId: String, cipherText: String) {
        self.messageId = UUID().uuidString.lowercased()
        self.status = MessageStatus.SENT.rawValue
        self.conversationId = conversationId
        self.recipientId = recipientId
        self.data = cipherText
        self.category = MessageCategory.SIGNAL_KEY.rawValue
    }

    init(consumeSignalKeys recipients: [BlazeSessionMessageParam]) {
        self.recipients = recipients
    }

    init(syncSignalKeys keys: SignalKeyRequest) {
        self.keys = keys
    }

    init(messages: [TransferMessage]) {
        self.messages = messages
    }

    init(sessionId: String, messages: [TransferMessage]) {
        let accountId = AccountAPI.shared.accountUserId
        let transferPlainData = TransferPlainAckData(action: PlainDataAction.ACKNOWLEDGE_MESSAGE_RECEIPTS.rawValue, messages: messages)
        self.messageId = UUID().uuidString.lowercased()
        self.conversationId = accountId
        self.recipientId = accountId
        self.category = MessageCategory.PLAIN_JSON.rawValue
        self.data = (try? JSONEncoder().encode(transferPlainData).base64EncodedString()) ?? ""
        self.status = MessageStatus.SENDING.rawValue
        self.sessionId = sessionId
        self.primitiveId = accountId
    }

    init(conversationId: String, recipientId: String? = nil, category: String? = nil, data: String? = nil, offset: String? = nil, status: String? = nil, messageId: String? = nil, quoteMessageId: String? = nil, keys: SignalKeyRequest? = nil, recipients: [BlazeSessionMessageParam]? = nil, messages: [TransferMessage]? = nil, sessionId: String? = nil, primitiveId: String? = nil, primitiveMessageId: String? = nil, representativeId: String? = nil) {
        self.conversationId = conversationId
        self.recipientId = recipientId
        self.category = category
        self.data = data
        self.offset = offset

        self.status = status
        self.messageId = messageId
        self.quoteMessageId = quoteMessageId

        self.keys = keys
        self.recipients = recipients
        self.messages = messages

        self.sessionId = sessionId
        self.primitiveId = primitiveId
        self.primitiveMessageId = primitiveMessageId

        self.representativeId = representativeId
    }
}
