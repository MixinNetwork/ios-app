import MixinServices

extension TransferPinAction {
    
    static func getPinMessage(userId: String, userFullName: String, category: String, content: String?) -> String {
        let uFullName = userId == myUserId ? R.string.localizable.chat_message_you() : userFullName
        if category.hasSuffix("_TEXT"), let content = content {
            return R.string.localizable.chat_pinned_text_message(uFullName, content)
        } else if category.hasSuffix("_AUDIO") {
            return R.string.localizable.chat_pinned_audio_message(uFullName)
        } else if category.hasSuffix("_IMAGE") {
            return R.string.localizable.chat_pinned_image_message(uFullName)
        } else if category.hasSuffix("_VIDEO") {
            return R.string.localizable.chat_pinned_video_message(uFullName)
        } else if category.hasSuffix("_LIVE") {
            return R.string.localizable.chat_pinned_live_message(uFullName)
        } else if category.hasSuffix("_STICKER") {
            return R.string.localizable.chat_pinned_sticker_message(uFullName)
        } else if category.hasSuffix("_DATA") {
            return R.string.localizable.chat_pinned_data_message(uFullName)
        } else if category.hasSuffix("_CONTACT") {
            return R.string.localizable.chat_pinned_contact_message(uFullName)
        } else if category.hasSuffix("_POST") {
            return R.string.localizable.chat_pinned_post_message(uFullName)
        } else if category.hasSuffix("_LOCATION") {
            return R.string.localizable.chat_pinned_location_message(uFullName)
        } else if category.hasSuffix("_TRANSCRIPT") {
            return R.string.localizable.chat_pinned_transcript_message(uFullName)
        } else {
            return R.string.localizable.chat_pinned_general_message(uFullName)
        }
    }
    
    static func getPinMessage(userId: String, userFullName: String, content: String) -> String {
        guard let data = content.data(using: .utf8),
              let localContent = (try? JSONDecoder.default.decode(PinMessage.LocalContent.self, from: data))
        else {
            let uFullName = userId == myUserId ? R.string.localizable.chat_message_you() : userFullName
            return R.string.localizable.chat_pinned_general_message(uFullName)
        }
        return getPinMessage(userId: userId, userFullName: userFullName, category: localContent.category, content: localContent.content)
    }
    
    static func getPinPreview(userId: String, userFullName: String, category: String, content: String?) -> String {
        let uFullName = userId == myUserId ? R.string.localizable.chat_message_you() : userFullName
        if category.hasSuffix("_TEXT"), let content = content {
            return R.string.localizable.chat_pinned_preview_text_message(uFullName, content)
        } else if category.hasSuffix("_AUDIO") {
            return R.string.localizable.chat_pinned_preview_audio_message(uFullName)
        } else if category.hasSuffix("_IMAGE") {
            return R.string.localizable.chat_pinned_preview_image_message(uFullName)
        } else if category.hasSuffix("_VIDEO") {
            return R.string.localizable.chat_pinned_preview_video_message(uFullName)
        } else if category.hasSuffix("_LIVE") {
            return R.string.localizable.chat_pinned_preview_live_message(uFullName)
        } else if category.hasSuffix("_STICKER") {
            return R.string.localizable.chat_pinned_preview_sticker_message(uFullName)
        } else if category.hasSuffix("_DATA") {
            return R.string.localizable.chat_pinned_preview_data_message(uFullName)
        } else if category.hasSuffix("_CONTACT") {
            return R.string.localizable.chat_pinned_preview_contact_message(uFullName)
        } else if category.hasSuffix("_POST") {
            return R.string.localizable.chat_pinned_preview_post_message(uFullName)
        } else if category.hasSuffix("_LOCATION") {
            return R.string.localizable.chat_pinned_preview_location_message(uFullName)
        } else if category.hasSuffix("_TRANSCRIPT") {
            return R.string.localizable.chat_pinned_preview_transcript_message(uFullName)
        } else {
            return R.string.localizable.chat_pinned_preview_general_message(uFullName)
        }
    }
    
}
