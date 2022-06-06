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
        let isParticipantMyself = participantId == myUserId
        let operatorName = userId == myUserId ? R.string.localizable.you() : userFullName
        let participantName = isParticipantMyself ? R.string.localizable.you() : participantFullName ?? ""
        let operateeName = isParticipantMyself ? R.string.localizable.you().lowercased() : participantFullName ?? ""
        switch action {
        case SystemConversationAction.CREATE.rawValue:
            return R.string.localizable.created_this_group(operatorName)
        case SystemConversationAction.ADD.rawValue:
            return R.string.localizable.chat_group_add(operatorName, operateeName)
        case SystemConversationAction.REMOVE.rawValue:
            return R.string.localizable.chat_group_remove(operatorName, operateeName)
        case SystemConversationAction.JOIN.rawValue:
            return R.string.localizable.chat_group_join(participantName)
        case SystemConversationAction.EXIT.rawValue:
            return R.string.localizable.chat_group_exit(participantName)
        case SystemConversationAction.ROLE.rawValue:
            return R.string.localizable.now_an_addmin(participantName)
        case SystemConversationAction.EXPIRE.rawValue:
            if let expireIn = content?.int64Value {
                if expireIn == 0 {
                    return R.string.localizable.disable_disappearing_message(operatorName)
                } else {
                    let title = ExpiredMessageDurationFormatter.string(from: expireIn)
                    return R.string.localizable.set_disappearing_message_time_to(operatorName, title)
                }
            } else {
                return R.string.localizable.changed_disappearing_message_settings(operatorName)
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
