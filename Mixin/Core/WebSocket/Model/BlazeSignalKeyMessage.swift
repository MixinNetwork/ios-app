import Foundation

struct BlazeSignalMessage: Codable {

    let messageId: String
    let recipientId: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case recipientId = "recipient_id"
        case data
    }
}

extension BlazeSignalMessage {

    init(recipientId: String, data: String) {
        self.messageId = UUID().uuidString.lowercased()
        self.recipientId = recipientId
        self.data = data
    }
}
