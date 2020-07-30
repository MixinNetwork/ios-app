import Foundation
import UserNotifications

public extension UNMutableNotificationContent {
    
    convenience init(message: MessageItem, ownerUser: UserItem?, conversation: ConversationItem) {
        self.init()
        
        let conversationIsGroup = conversation.isGroup()
        let isRepresentativeMessage = message.isRepresentativeMessage(conversation: conversation)
        
        if conversationIsGroup {
            title = conversation.name
        } else if isRepresentativeMessage {
            title = conversation.ownerFullName
        } else {
            title = message.userFullName
        }
        
        if AppGroupUserDefaults.User.showMessagePreviewInNotification {
            body = messagePreview(conversationIsGroup: conversationIsGroup,
                                  isRepresentativeMessage: isRepresentativeMessage,
                                  message: message)
        } else {
            body = Localized.NOTIFICATION_CONTENT_GENERAL
        }
        
        userInfo[UserInfoKey.conversationId] = conversation.conversationId
        userInfo[UserInfoKey.conversationCategory] = conversation.category
        userInfo[UserInfoKey.messageId] = message.messageId
        ownerUser?.notificationUserInfo.forEach({ (key, value) in
            userInfo[key] = value
        })
        
        sound = .mixin
        categoryIdentifier = NotificationCategoryIdentifier.message
        threadIdentifier = conversation.conversationId
    }
    
    private func messagePreview(conversationIsGroup: Bool, isRepresentativeMessage: Bool, message: MessageItem) -> String {
        if message.category.hasSuffix("_TEXT") {
            if conversationIsGroup || isRepresentativeMessage {
                return "\(message.userFullName): \(message.mentionedFullnameReplacedContent)"
            } else {
                return message.mentionedFullnameReplacedContent
            }
        } else if message.category.hasSuffix("_IMAGE") {
            if conversationIsGroup || isRepresentativeMessage {
                return Localized.ALERT_KEY_GROUP_IMAGE_MESSAGE(fullname: message.userFullName)
            } else {
                return Localized.ALERT_KEY_CONTACT_IMAGE_MESSAGE
            }
        } else if message.category.hasSuffix("_VIDEO") {
            if conversationIsGroup || isRepresentativeMessage {
                return Localized.ALERT_KEY_GROUP_VIDEO_MESSAGE(fullname: message.userFullName)
            } else {
                return Localized.ALERT_KEY_CONTACT_VIDEO_MESSAGE
            }
        } else if message.category.hasSuffix("_LIVE") {
            if conversationIsGroup || isRepresentativeMessage {
                return Localized.ALERT_KEY_GROUP_LIVE_MESSAGE(fullname: message.userFullName)
            } else {
                return Localized.ALERT_KEY_CONTACT_LIVE_MESSAGE
            }
        } else if message.category.hasSuffix("_AUDIO") {
            if conversationIsGroup || isRepresentativeMessage {
                return Localized.ALERT_KEY_GROUP_AUDIO_MESSAGE(fullname: message.userFullName)
            } else {
                return Localized.ALERT_KEY_CONTACT_AUDIO_MESSAGE
            }
        } else if message.category.hasSuffix("_DATA") {
            if conversationIsGroup || isRepresentativeMessage {
                return Localized.ALERT_KEY_GROUP_DATA_MESSAGE(fullname: message.userFullName)
            } else {
                return Localized.ALERT_KEY_CONTACT_DATA_MESSAGE
            }
        } else if message.category.hasSuffix("_STICKER") {
            if conversationIsGroup || isRepresentativeMessage {
                return Localized.ALERT_KEY_GROUP_STICKER_MESSAGE(fullname: message.userFullName)
            } else {
                return Localized.ALERT_KEY_CONTACT_STICKER_MESSAGE
            }
        } else if message.category.hasSuffix("_CONTACT") {
            if conversationIsGroup || isRepresentativeMessage {
                return Localized.ALERT_KEY_GROUP_CONTACT_MESSAGE(fullname: message.userFullName)
            } else {
                return Localized.ALERT_KEY_CONTACT_CONTACT_MESSAGE
            }
        } else if message.category.hasSuffix("_POST") {
            if conversationIsGroup || isRepresentativeMessage {
                return "\(message.userFullName): \(message.markdownControlCodeRemovedContent)"
            } else {
                return message.markdownControlCodeRemovedContent
            }
        } else if message.category.hasSuffix("_LOCATION") {
            if conversationIsGroup || isRepresentativeMessage {
                return Localized.ALERT_KEY_GROUP_LOCATION_MESSAGE(fullname: message.userFullName)
            } else {
                return Localized.ALERT_KEY_CONTACT_LOCATION_MESSAGE
            }
        } else if message.category.hasPrefix("KRAKEN_") {
            return Localized.ALERT_KEY_GROUP_AUDIO_INVITE_MESSAGE(fullname: message.userFullName)
        } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            switch message.snapshotType {
            case SnapshotType.deposit.rawValue:
                return Localized.NOTIFICATION_CONTENT_DEPOSIT
            case SnapshotType.transfer.rawValue:
                return Localized.ALERT_KEY_CONTACT_TRANSFER_MESSAGE
            case SnapshotType.withdrawal.rawValue:
                return Localized.NOTIFICATION_CONTENT_WITHDRAWAL
            case SnapshotType.fee.rawValue:
                return Localized.NOTIFICATION_CONTENT_FEE
            case SnapshotType.rebate.rawValue:
                return Localized.NOTIFICATION_CONTENT_REBATE
            default:
                return Localized.NOTIFICATION_CONTENT_GENERAL
            }
        } else if message.category == MessageCategory.WEBRTC_AUDIO_OFFER.rawValue {
            return Localized.ALERT_KEY_CONTACT_AUDIO_CALL_MESSAGE
        } else if message.category == MessageCategory.WEBRTC_AUDIO_CANCEL.rawValue {
            return Localized.ALERT_KEY_CONTACT_AUDIO_CALL_CANCELLED_MESSAGE
        } else {
            return Localized.NOTIFICATION_CONTENT_GENERAL
        }
    }
    
}
