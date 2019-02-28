import Foundation

struct BlazeAckMessage: Codable {

    let messageId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case status
    }
}
