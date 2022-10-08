import Foundation
import MixinServices

extension ConversationItem {
    
    var displayContent: String {
        if messageStatus == MessageStatus.FAILED.rawValue {
            return R.string.localizable.chat_decryption_failed_hint(senderFullName)
        } else if messageStatus == MessageStatus.UNKNOWN.rawValue {
            return R.string.localizable.message_not_support()
        } else {
            let senderIsMe = senderId == myUserId
            let senderName = senderIsMe ? R.string.localizable.you() : senderFullName
            let category = contentType
            if category.hasSuffix("_TEXT") {
                if isGroup() {
                    return "\(senderName): \(mentionedFullnameReplacedContent)"
                } else {
                    return mentionedFullnameReplacedContent
                }
            } else if category.hasSuffix("_IMAGE") {
                if isGroup() {
                    return "\(senderName): \(R.string.localizable.content_photo())"
                } else {
                    return R.string.localizable.content_photo()
                }
            } else if category.hasSuffix("_STICKER") {
                if isGroup() {
                    return "\(senderName): \(R.string.localizable.content_sticker())"
                } else {
                    return R.string.localizable.content_sticker()
                }
            } else if category.hasSuffix("_CONTACT") {
                if isGroup() {
                    return "\(senderName): \(R.string.localizable.content_contact())"
                } else {
                    return R.string.localizable.content_contact()
                }
            } else if category.hasSuffix("_DATA") {
                if isGroup() {
                    return "\(senderName): \(R.string.localizable.content_file())"
                } else {
                    return R.string.localizable.content_file()
                }
            } else if category.hasSuffix("_VIDEO") {
                if isGroup() {
                    return "\(senderName): \(R.string.localizable.content_video())"
                } else {
                    return R.string.localizable.content_video()
                }
            } else if category.hasSuffix("_LIVE") {
                if isGroup() {
                    return "\(senderName): \(R.string.localizable.content_live())"
                } else {
                    return R.string.localizable.content_live()
                }
            } else if category.hasSuffix("_AUDIO") {
                if isGroup() {
                    return "\(senderName): \(R.string.localizable.content_audio())"
                } else {
                    return R.string.localizable.content_audio()
                }
            } else if category.hasSuffix("_POST") {
                if isGroup() {
                    return "\(senderName): \(markdownControlCodeRemovedContent)"
                } else {
                    return markdownControlCodeRemovedContent
                }
            } else if category.hasSuffix("_LOCATION") {
                if isGroup() {
                    return "\(senderName): \(R.string.localizable.content_location())"
                } else {
                    return R.string.localizable.content_location()
                }
            } else if category.hasPrefix("WEBRTC_") {
                return R.string.localizable.content_voice()
            } else if category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
                return R.string.localizable.content_transfer()
            } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue {
                return (appButtons?.map({ (appButton) -> String in
                    return "[\(appButton.label)]"
                }) ?? []).joined()
            } else if category == MessageCategory.APP_CARD.rawValue, let appCard = appCard {
                return "[\(appCard.title)]"
            } else if category == MessageCategory.MESSAGE_RECALL.rawValue {
                if senderIsMe {
                    return R.string.localizable.you_deleted_this_message()
                } else {
                    return R.string.localizable.this_message_was_deleted()
                }
            } else if category == MessageCategory.MESSAGE_PIN.rawValue {
                return TransferPinAction.pinMessage(item: self)
            } else if category == MessageCategory.KRAKEN_PUBLISH.rawValue {
                return R.string.localizable.started_group_call(senderName)
            } else if category == MessageCategory.KRAKEN_CANCEL.rawValue {
                return R.string.localizable.chat_group_call_cancel(senderName)
            } else if category == MessageCategory.KRAKEN_DECLINE.rawValue {
                return R.string.localizable.chat_group_call_decline(senderName)
            } else if category == MessageCategory.KRAKEN_INVITE.rawValue {
                return R.string.localizable.chat_group_call_invite(senderName)
            } else if category == MessageCategory.KRAKEN_END.rawValue {
                return R.string.localizable.content_group_call_ended()
            } else if category.hasSuffix("_TRANSCRIPT") {
                return R.string.localizable.content_transcript()
            } else {
                if contentType.hasPrefix("SYSTEM_") {
                    return SystemConversationAction.getSystemMessage(actionName: actionName,
                                                                     userId: senderId,
                                                                     userFullName: senderFullName,
                                                                     participantId: participantUserId,
                                                                     participantFullName: participantFullName,
                                                                     content: content)
                } else if messageId.isEmpty {
                    return ""
                } else {
                    return R.string.localizable.message_not_support()
                }
            }
        }
    }
    
}
