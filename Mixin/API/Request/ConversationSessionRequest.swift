import Foundation

struct ConversationSessionRequest: Encodable {

    let action: String
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case action
        case sessionId = "session_id"
    }

}
