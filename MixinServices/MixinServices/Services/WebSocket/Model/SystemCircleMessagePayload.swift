import Foundation

struct SystemCircleMessagePayload: Codable {

    let action: String
    let circleId: String
    let conversationId: String?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case action
        case circleId = "circle_id"
        case conversationId = "conversation_id"
        case userId = "user_id"
    }
}

enum SystemCircleMessageAction: String {
    case CREATE
    case DELETE
    case UPDATE

    case ADD
    case REMOVE
}

extension SystemCircleMessagePayload {

    func makeConversationIdIfNeeded() -> String? {
        if conversationId != nil {
            return conversationId
        } else if let userId = userId {
            return ConversationDAO.shared.makeConversationId(userId: userId, ownerUserId: myUserId)
        }
        return nil
    }

}
