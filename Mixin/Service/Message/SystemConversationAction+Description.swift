import MixinServices

extension SystemConversationAction {

    static func getSystemMessage(actionName: String?, userId: String, userFullName: String, participantId: String?, participantFullName: String?, content: String, expireIn: Int64) -> String {
        let action = actionName ?? ""
        let uFullName = userId == myUserId ? R.string.localizable.chat_message_you() : userFullName
        let pFullName = participantId == myUserId ? R.string.localizable.chat_message_you() : participantFullName ?? ""
        switch action {
        case SystemConversationAction.CREATE.rawValue:
            return R.string.localizable.chat_message_created(uFullName)
        case SystemConversationAction.ADD.rawValue:
            return R.string.localizable.chat_message_added(uFullName, pFullName)
        case SystemConversationAction.REMOVE.rawValue:
            return R.string.localizable.chat_message_removed(uFullName, pFullName)
        case SystemConversationAction.JOIN.rawValue:
            return R.string.localizable.chat_message_joined(pFullName)
        case SystemConversationAction.EXIT.rawValue:
            return R.string.localizable.chat_message_left(pFullName)
        case SystemConversationAction.ROLE.rawValue:
            return R.string.localizable.chat_message_admin(pFullName)
        case SystemConversationAction.EXPIRE.rawValue:
            if expireIn == 0 {
                return R.string.localizable.disappearing_message_turn_off(uFullName)
            } else {
                let title = DisappearingMessageDurationFormatter.string(from: expireIn)
                return R.string.localizable.disappearing_message_turn_on(uFullName, title)
            }
        default:
            return R.string.localizable.chat_cell_title_unknown_category()
        }
    }
}
