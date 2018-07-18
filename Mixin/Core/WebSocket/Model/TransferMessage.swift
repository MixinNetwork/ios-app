import Foundation

struct TransferMessage: Codable {

    let messageId: String
    let recipientId: String?
    let data: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case recipientId = "recipient_id"
        case data
        case status
    }
}

extension TransferMessage {

    init(recipientId: String, data: String) {
        self.messageId = UUID().uuidString.lowercased()
        self.recipientId = recipientId
        self.data = data
        self.status = nil
    }

    init(messageId: String, status: String) {
        self.messageId = messageId
        self.status = status
        self.recipientId = nil
        self.data = nil
    }
}
