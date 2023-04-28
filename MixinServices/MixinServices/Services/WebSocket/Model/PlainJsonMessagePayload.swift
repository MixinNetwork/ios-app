import Foundation

struct PlainJsonMessagePayload: Codable {

    let action: String
    let messages: [String]?
    var ackMessages: [TransferMessage]?
    let content: String? // DeviceTransferCommandData

    enum CodingKeys: String, CodingKey {
        case action
        case messages
        case ackMessages = "ack_messages"
        case content
    }
    
}

enum PlainDataAction: String {
    case RESEND_KEY
    case NO_KEY
    case RESEND_MESSAGES
    case ACKNOWLEDGE_MESSAGE_RECEIPTS
    case DEVICE_TRANSFER
}
