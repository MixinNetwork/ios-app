import Foundation

struct TransferPlainData: Codable {

    let action: String
    let messages: [String]?

    enum CodingKeys: String, CodingKey {
        case action
        case messages
    }
}

enum PlainDataAction: String {
    case RESEND_KEY
    case NO_KEY
    case RESEND_MESSAGES
}
