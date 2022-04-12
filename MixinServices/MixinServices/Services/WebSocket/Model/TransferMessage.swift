import Foundation

struct TransferMessage: Codable {

    let messageId: String
    let recipientId: String?
    let data: String?
    let status: String?
    let sessionId: String?
    let expireAt: Int64?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case recipientId = "recipient_id"
        case data
        case status
        case sessionId = "session_id"
        case expireAt = "expire_at"
    }
}

extension TransferMessage {

    init(recipientId: String, data: String, status: String? = nil, sessionId: String? = nil, expireAt: Int64? = nil) {
        self.messageId = UUID().uuidString.lowercased()
        self.recipientId = recipientId
        self.data = data
        self.status = status
        self.sessionId = sessionId
        self.expireAt = expireAt
    }

    init(messageId: String, status: String, expireAt: Int64? = nil) {
        self.messageId = messageId
        self.status = status
        self.recipientId = nil
        self.data = nil
        self.sessionId = nil
        self.expireAt = expireAt
    }
}
