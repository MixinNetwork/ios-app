import MixinServices

enum RecalledMessage {

    static func description(item: MessageItem) -> String {
        if let participantUserId = item.participantUserId {
            description(actorId: participantUserId, actorName: item.participantFullName)
        } else {
            description(actorId: item.userId, actorName: item.userFullName)
        }
    }

    static func description(item: ConversationItem) -> String {
        if let participantUserId = item.participantUserId {
            description(actorId: participantUserId, actorName: item.participantFullName)
        } else {
            description(actorId: item.senderId, actorName: item.senderFullName)
        }
    }

    private static func description(actorId: String, actorName: String?) -> String {
        if actorId == myUserId {
            return R.string.localizable.you_deleted_this_message()
        } else if let actorName, !actorName.isEmpty {
            return R.string.localizable.deleted_this_message(actorName)
        } else {
            return R.string.localizable.this_message_was_deleted()
        }
    }

}
