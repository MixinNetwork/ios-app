import Foundation

struct TransferPlainData: Codable {

    let action: String
    let messageId: String?
    let messages: [String]?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case action
        case messageId = "message_id"
        case messages
        case status
    }
}

enum PlainDataAction: String {
    case RESEND_KEY
    case NO_KEY
    case RESEND_MESSAGES
    case ACKNOWLEDGE_MESSAGE_RECEIPT
    case SYNC_SESSION
}
