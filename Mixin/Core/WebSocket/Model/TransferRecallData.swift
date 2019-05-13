import Foundation

struct TransferRecallData: Codable {

    let messageId: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }

}
