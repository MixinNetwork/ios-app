import Foundation

struct TransferPlainAckData: Codable {

    let action: String
    let messages: [BlazeAckMessage]

    enum CodingKeys: String, CodingKey {
        case action
        case messages
    }
}
