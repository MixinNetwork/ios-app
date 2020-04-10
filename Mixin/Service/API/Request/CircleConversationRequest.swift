import Foundation
import MixinServices

struct CircleConversationRequest {

    let action: CircleConversationAction
    let conversationId: String
    let userId: String?

    var jsonObject: [String: String] {
        var object = ["conversation_id": conversationId, "action": action.rawValue]
        if let userId = userId {
            object["user_id"] = userId
        }
        return object
    }

}

enum CircleConversationAction: String, Codable {
    case ADD
    case REMOVE
}

extension CircleConversationRequest {

    static func create(action: CircleConversationAction, member: CircleMember) -> CircleConversationRequest {
        if member.category == ConversationCategory.CONTACT.rawValue {
            return CircleConversationRequest(action: action, conversationId: member.conversationId, userId: member.userId)
        } else {
            return CircleConversationRequest(action: action, conversationId: member.conversationId, userId: nil)
        }
    }

}
