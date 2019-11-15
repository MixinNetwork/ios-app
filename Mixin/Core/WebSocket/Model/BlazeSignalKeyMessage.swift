import Foundation

struct BlazeSignalKeyMessage: Codable {

    let messageId: String
    let recipientId: String?
    let data: String?
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case recipientId = "recipient_id"
        case data
        case sessionId = "session_id"
    }
}

extension BlazeSignalKeyMessage {

    init(recipientId: String, data: String, sessionId: String? = nil) {
        self.messageId = UUID().uuidString.lowercased()
        self.recipientId = recipientId
        self.data = data
        self.sessionId = sessionId
    }
}
