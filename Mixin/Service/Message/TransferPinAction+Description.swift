import MixinServices

extension TransferPinAction {
    
    static func pinMessage(item: ConversationItem) -> String {
        let category: String
        if let content = item.content, let localContent = TransferPinAction.pinMessageLocalContent(from: content) {
            if localContent.category.hasSuffix("_TEXT"), let content = localContent.content {
                item.content = content
            }
            category = localContent.category
        } else {
            category = ""
        }
        return TransferPinAction.pinMessage(userId: item.senderId, userName: item.senderFullName, category: category, content: item.mentionedFullnameReplacedContent)
    }
    
    static func pinMessage(item: MessageItem) -> String {
        let category: String
        if let content = item.content, let localContent = TransferPinAction.pinMessageLocalContent(from: content) {
            if localContent.category.hasSuffix("_TEXT"), let content = localContent.content {
                item.content = content
            }
            category = localContent.category
        } else {
            category = ""
        }
        return TransferPinAction.pinMessage(userId: item.userId, userName: item.userFullName, category: category, content: item.mentionedFullnameReplacedContent)
    }
    
    static func isPinnedText(item: MessageItem) -> Bool {
        if let content = item.content, let localContent = TransferPinAction.pinMessageLocalContent(from: content), localContent.category.hasSuffix("_TEXT") {
            return true
        }
        return false
    }
    
    private static func pinMessage(userId: String, userName: String?, category: String, content: String) -> String {
        let userFullName = userId == myUserId ? R.string.localizable.you() : (userName ?? "")
        if category.hasSuffix("_TEXT") {
            return R.string.localizable.chat_pin_message(userFullName, "\"\(content)\"")
        } else if category.hasSuffix("_IMAGE") {
            return R.string.localizable.pinned_a_image(userFullName)
        } else if category.hasSuffix("_STICKER") {
            return R.string.localizable.pinned_a_sticker(userFullName)
        } else if category.hasSuffix("_CONTACT") {
            return R.string.localizable.pinned_a_contact(userFullName)
        } else if category.hasSuffix("_DATA") {
            return R.string.localizable.pinned_a_file(userFullName)
        } else if category.hasSuffix("_VIDEO") {
            return R.string.localizable.pinned_a_video(userFullName)
        } else if category.hasSuffix("_LIVE") {
            return R.string.localizable.pinned_a_live(userFullName)
        } else if category.hasSuffix("_AUDIO") {
            return R.string.localizable.pinned_a_audio(userFullName)
        } else if category.hasSuffix("_POST") {
            return R.string.localizable.pinned_a_post(userFullName)
        } else if category.hasSuffix("_LOCATION") {
            return R.string.localizable.pinned_a_location(userFullName)
        } else if category.hasSuffix("_TRANSCRIPT") {
            return R.string.localizable.pinned_a_transcript(userFullName)
        } else if category == MessageCategory.APP_CARD.rawValue {
            return R.string.localizable.pinned_a_card(userFullName)
        } else {
            return R.string.localizable.pinned_a_general(userFullName)
        }
    }
    
    private static func pinMessageLocalContent(from content: String) -> PinMessage.LocalContent? {
        guard let data = content.data(using: .utf8), let localContent = try? JSONDecoder.default.decode(PinMessage.LocalContent.self, from: data) else {
            return nil
        }
        return localContent
    }
    
}
