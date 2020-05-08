import MixinServices

extension MessageItem {
    
    var allowedActions: [MessageAction] {
        var actions = [MessageAction]()
        if status == MessageStatus.FAILED.rawValue || category.hasPrefix("WEBRTC_") {
            actions = [.delete]
        } else if category.hasSuffix("_TEXT") || category.hasSuffix("_POST") {
            actions = [.reply, .forward, .copy, .delete]
        } else if category.hasSuffix("_STICKER") {
            actions = [.addToStickers, .reply, .forward, .delete]
        } else if category.hasSuffix("_CONTACT") || category.hasSuffix("_LIVE") {
            actions = [.reply, .forward, .delete]
        } else if category.hasSuffix("_IMAGE") {
            if mediaStatus == MediaStatus.DONE.rawValue || mediaStatus == MediaStatus.READ.rawValue {
                actions = [.addToStickers, .reply, .forward, .delete]
            } else {
                actions = [.reply, .delete]
            }
        } else if category.hasSuffix("_DATA") || category.hasSuffix("_VIDEO") || category.hasSuffix("_AUDIO") {
            if mediaStatus == MediaStatus.DONE.rawValue || mediaStatus == MediaStatus.READ.rawValue {
                actions = [.reply, .forward, .delete]
            } else {
                actions = [.reply, .delete]
            }
        } else if category.hasSuffix("_LOCATION") {
            actions = [.forward, .reply, .delete]
        } else if category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            actions = [.delete]
        } else if category == MessageCategory.APP_CARD.rawValue {
            actions = [.forward, .reply, .delete]
        } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue {
            actions = [.delete]
        } else if category == MessageCategory.MESSAGE_RECALL.rawValue {
            actions = [.delete]
        } else {
            actions = []
        }
        if ConversationViewController.allowReportSingleMessage {
            actions.append(.report)
        }
        return actions
    }
    
}
