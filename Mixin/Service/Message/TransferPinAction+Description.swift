import MixinServices

extension TransferPinAction {
    
    static func pinMessage(userId: String, userFullName: String, category: String, content: String? = nil) -> String {
        if category.hasSuffix("_TEXT"), let content = content {
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
    
    static func pinMessagePreview(item: MessageItem, isGroup: Bool) -> String {
        let senderName = item.userId == myUserId ? R.string.localizable.chat_message_you() : (item.userFullName ?? "")
        let category = item.category
        if category.hasSuffix("_TEXT") {
            let content = item.mentionedFullnameReplacedContent
            if isGroup {
                return "\(senderName): \(content)"
            } else {
                return content
            }
        } else if category.hasSuffix("_IMAGE") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_photo())"
            } else {
                return R.string.localizable.notification_content_photo()
            }
        } else if category.hasSuffix("_STICKER") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_sticker())"
            } else {
                return R.string.localizable.notification_content_sticker()
            }
        } else if category.hasSuffix("_CONTACT") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_contact())"
            } else {
                return R.string.localizable.notification_content_contact()
            }
        } else if category.hasSuffix("_DATA") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_file())"
            } else {
                return R.string.localizable.notification_content_file()
            }
        } else if category.hasSuffix("_VIDEO") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_video())"
            } else {
                return R.string.localizable.notification_content_video()
            }
        } else if category.hasSuffix("_LIVE") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_live())"
            } else {
                return R.string.localizable.notification_content_live()
            }
        } else if category.hasSuffix("_AUDIO") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_audio())"
            } else {
                return R.string.localizable.notification_content_audio()
            }
        } else if category.hasSuffix("_POST") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_post())"
            } else {
                return R.string.localizable.notification_content_post()
            }
        } else if category.hasSuffix("_LOCATION") {
            if isGroup {
                return "\(senderName): \(R.string.localizable.notification_content_location())"
            } else {
                return R.string.localizable.notification_content_location()
            }
        } else if category.hasSuffix("_TRANSCRIPT") {
            return R.string.localizable.notification_content_transcript()
        } else {
            return R.string.localizable.chat_cell_title_unknown_category()
        }
    }
    
}
