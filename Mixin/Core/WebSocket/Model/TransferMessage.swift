import Foundation

struct TransferMessage: Codable {

    let messageId: String
    let recipientId: String?
    let data: String?
    let status: String?
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case recipientId = "recipient_id"
        case data
        case status
        case sessionId = "session_id"
    }
}

extension TransferMessage {

    init(recipientId: String, data: String, status: String? = nil, sessionId: String? = nil) {
        self.messageId = UUID().uuidString.lowercased()
        self.recipientId = recipientId
        self.data = data
        self.status = status
        self.sessionId = sessionId
    }

    init(messageId: String, status: String) {
        self.messageId = messageId
        self.status = status
        self.recipientId = nil
        self.data = nil
        self.sessionId = nil
    }
}
