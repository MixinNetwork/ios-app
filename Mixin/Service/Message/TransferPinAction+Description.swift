import MixinServices

extension TransferPinAction {
    
    static func pinMessage(item: ConversationItem) -> String {
        let category: String
        if let localContent = TransferPinAction.pinMessageLocalContent(from: item.content) {
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
    
    private static func pinMessage(userId: String, userName: String?, category: String, content: String) -> String {
        let userFullName = userId == myUserId ? R.string.localizable.chat_message_you() : (userName ?? "")
        if category.hasSuffix("_TEXT") {
            return R.string.localizable.chat_pinned_text_message(userFullName, content)
        } else if category.hasSuffix("_IMAGE") {
            return R.string.localizable.chat_pinned_image_message(userFullName)
        } else if category.hasSuffix("_STICKER") {
            return R.string.localizable.chat_pinned_sticker_message(userFullName)
        } else if category.hasSuffix("_CONTACT") {
            return R.string.localizable.chat_pinned_contact_message(userFullName)
        } else if category.hasSuffix("_DATA") {
            return R.string.localizable.chat_pinned_data_message(userFullName)
        } else if category.hasSuffix("_VIDEO") {
            return R.string.localizable.chat_pinned_video_message(userFullName)
        } else if category.hasSuffix("_LIVE") {
            return R.string.localizable.chat_pinned_live_message(userFullName)
        } else if category.hasSuffix("_AUDIO") {
            return R.string.localizable.chat_pinned_audio_message(userFullName)
        } else if category.hasSuffix("_POST") {
            return R.string.localizable.chat_pinned_post_message(userFullName)
        } else if category.hasSuffix("_LOCATION") {
            return R.string.localizable.chat_pinned_location_message(userFullName)
        } else if category.hasSuffix("_TRANSCRIPT") {
            return R.string.localizable.chat_pinned_transcript_message(userFullName)
        } else {
            return R.string.localizable.chat_pinned_general_message(userFullName)
        }
    }
    
    private static func pinMessageLocalContent(from content: String) -> PinMessage.LocalContent? {
        guard let data = content.data(using: .utf8), let localContent = try? JSONDecoder.default.decode(PinMessage.LocalContent.self, from: data) else {
            return nil
        }
        return localContent
    }
    
}
