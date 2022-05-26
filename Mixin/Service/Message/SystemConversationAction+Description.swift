import MixinServices

extension SystemConversationAction {

    static func getSystemMessage(
        actionName: String?,
        userId: String,
        userFullName: String,
        participantId: String?,
        participantFullName: String?,
        content: String?
    ) -> String {
        let action = actionName ?? ""
        let uFullName = userId == myUserId ? R.string.localizable.you() : userFullName
        let pFullName = participantId == myUserId ? R.string.localizable.you() : participantFullName ?? ""
        switch action {
        case SystemConversationAction.CREATE.rawValue:
            return R.string.localizable.created_this_group(uFullName)
        case SystemConversationAction.ADD.rawValue:
            return R.string.localizable.chat_group_add(uFullName, pFullName)
        case SystemConversationAction.REMOVE.rawValue:
            return R.string.localizable.chat_group_remove(uFullName, pFullName)
        case SystemConversationAction.JOIN.rawValue:
            return R.string.localizable.chat_group_join(pFullName)
        case SystemConversationAction.EXIT.rawValue:
            return R.string.localizable.chat_group_exit(pFullName)
        case SystemConversationAction.ROLE.rawValue:
            return R.string.localizable.now_an_addmin(pFullName)
        case SystemConversationAction.EXPIRE.rawValue:
            if let expireIn = content?.int64Value {
                if expireIn == 0 {
                    return R.string.localizable.disable_disappearing_message(uFullName)
                } else {
                    let title = ExpiredMessageDurationFormatter.string(from: expireIn)
                    return R.string.localizable.set_disappearing_message_time_to(uFullName, title)
                }
            } else {
                return R.string.localizable.changed_disappearing_message_settings(uFullName)
            }
        default:
            if let content = content, !content.isEmpty {
                return content
            } else {
                return R.string.localizable.message_not_support()
            }
        }
    }
}
