import Foundation

struct TransferPlainAckData: Codable {

    let action: String
    let messages: [TransferMessage]

    enum CodingKeys: String, CodingKey {
        case action
        case messages
    }
}
