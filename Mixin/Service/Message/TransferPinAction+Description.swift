import MixinServices

extension TransferPinAction {
    
    static func getPinMessage(actionName: String?, userId: String, userFullName: String, content: String) -> String {
        let action = actionName ?? ""
        let uFullName = userId == myUserId ? R.string.localizable.chat_message_you() : userFullName
        switch action {
        case TransferPinAction.pin.rawValue:
            let pinAction = R.string.localizable.chat_pinned_message_action()
            return R.string.localizable.chat_pin_general_message(uFullName, pinAction)
        case TransferPinAction.unpin.rawValue:
            let pinAction = R.string.localizable.chat_unpinned_message_action()
            return R.string.localizable.chat_pin_general_message(uFullName, pinAction)
        default:
            return content
        }
    }
    
    func getMessagePreview(message: MessageItem) -> String {
        let action: String
        switch self {
        case .pin:
            action = R.string.localizable.chat_pinned_message_action()
        case .unpin:
            action = R.string.localizable.chat_unpinned_message_action()
        }
        let userFullName = message.userId == myUserId ? R.string.localizable.chat_message_you() : (message.userFullName ?? "")
        if message.category.hasSuffix("_TEXT"), let content = message.content {
            return R.string.localizable.chat_pin_text_message(userFullName, action, content)
        } else if message.category.hasSuffix("_AUDIO") {
            return R.string.localizable.chat_pin_audio_message(userFullName, action)
        } else if message.category.hasSuffix("_IMAGE") {
            return R.string.localizable.chat_pin_image_message(userFullName, action)
        } else if message.category.hasSuffix("_VIDEO") {
            return R.string.localizable.chat_pin_video_message(userFullName, action)
        } else if message.category.hasSuffix("_LIVE") {
            return R.string.localizable.chat_pin_live_message(userFullName, action)
        } else if message.category.hasSuffix("_STICKER") {
            return R.string.localizable.chat_pin_sticker_message(userFullName, action)
        } else if message.category.hasSuffix("_DATA") {
            return R.string.localizable.chat_pin_data_message(userFullName, action)
        } else if message.category.hasSuffix("_CONTACT") {
            return R.string.localizable.chat_pin_contact_message(userFullName, action)
        } else if message.category.hasSuffix("_POST") {
            return R.string.localizable.chat_pin_post_message(userFullName, action)
        } else if message.category.hasSuffix("_LOCATION") {
            return R.string.localizable.chat_pin_location_message(userFullName, action)
        } else if message.category.hasSuffix("_TRANSCRIPT") {
            return R.string.localizable.chat_pin_transcript_message(userFullName, action)
        } else {
            return R.string.localizable.chat_pin_general_message(userFullName, action)
        }
    }
    
}
