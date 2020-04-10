import Foundation

struct SystemUserMessagePayload: Codable {

    let action: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
    }
}

enum SystemUserMessageAction: String {
    case UPDATE
}
