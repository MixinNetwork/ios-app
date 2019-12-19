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

enum SystemConversationAction: String {
    case CREATE
    case UPDATE
    case ADD
    case REMOVE
    case JOIN
    case EXIT
    case ROLE

    static func getSystemMessage(actionName: String?, userId: String, userFullName: String, participantId: String?, participantFullName: String?, content: String) -> String {
        let action = actionName ?? ""
        let uFullName = userId == myUserId ? Localized.CHAT_MESSAGE_YOU : userFullName
        let pFullName = participantId == myUserId ? Localized.CHAT_MESSAGE_YOU : participantFullName ?? ""
        switch action {
        case SystemConversationAction.CREATE.rawValue:
            return Localized.CHAT_MESSAGE_CREATED(fullName: uFullName)
        case SystemConversationAction.ADD.rawValue:
            return Localized.CHAT_MESSAGE_ADDED(inviterFullName: uFullName, inviteeFullName: pFullName)
        case SystemConversationAction.REMOVE.rawValue:
            return Localized.CHAT_MESSAGE_REMOVED(adminFullName: uFullName, participantFullName: pFullName)
        case SystemConversationAction.JOIN.rawValue:
            return Localized.CHAT_MESSAGE_JOINED(fullName: pFullName)
        case SystemConversationAction.EXIT.rawValue:
            return Localized.CHAT_MESSAGE_LEFT(fullName: pFullName)
        case SystemConversationAction.ROLE.rawValue:
            return Localized.CHAT_MESSAGE_ADMIN(fullName: pFullName)
        default:
            return content
        }
    }
}
