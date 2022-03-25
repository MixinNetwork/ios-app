import Foundation

struct SystemConversationMessagePayload: Codable {

    let action: String
    let participantId: String?
    let userId: String?
    let role: String?
    let expireIn: UInt32?

    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
        case participantId = "participant_id"
        case role
        case expireIn = "expire_in"
    }
}

public enum SystemConversationAction: String {
    
    case CREATE
    case UPDATE
    case ADD
    case REMOVE
    case JOIN
    case EXIT
    case ROLE
    case DISAPPEARING
    
}
