import Foundation

struct ParticipantRequest: Codable {
    let userId: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
    }
}
