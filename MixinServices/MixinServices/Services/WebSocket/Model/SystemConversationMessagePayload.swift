import Foundation

struct SystemConversationMessagePayload: Codable {

    let action: String
    let participantId: String?
    let userId: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
        case participantId = "participant_id"
        case role
    }
}

enum SystemSessionMessageAction: String {
    case PROVISION
    case DESTROY
}

public enum SystemConversationAction: String {
    
    case CREATE
    case UPDATE
    case ADD
    case REMOVE
    case JOIN
    case EXIT
    case ROLE

    public static func getSystemMessage(actionName: String?, userId: String, userFullName: String, participantId: String?, participantFullName: String?, content: String) -> String {
        let action = actionName ?? ""
        let uFullName = userId == myUserId ? localized("chat_message_you") : userFullName
        let pFullName = participantId == myUserId ? localized("chat_message_you") : participantFullName ?? ""
        switch action {
        case SystemConversationAction.CREATE.rawValue:
            return localized("chat_message_created", arguments: [uFullName])
        case SystemConversationAction.ADD.rawValue:
            return localized("chat_message_added", arguments: [uFullName, pFullName])
        case SystemConversationAction.REMOVE.rawValue:
            return localized("chat_message_removed", arguments: [uFullName, pFullName])
        case SystemConversationAction.JOIN.rawValue:
            return localized("chat_message_joined", arguments: [pFullName])
        case SystemConversationAction.EXIT.rawValue:
            return localized("chat_message_left", arguments: [pFullName])
        case SystemConversationAction.ROLE.rawValue:
            return localized("chat_message_admin", arguments: [pFullName])
        default:
            return content
        }
    }
    
}
