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
            body = localized("notification_content_general")
        }
        
        userInfo[UserInfoKey.conversationId] = conversation.conversationId
        userInfo[UserInfoKey.conversationCategory] = conversation.category
        userInfo[UserInfoKey.messageId] = message.messageId
        ownerUser?.notificationUserInfo.forEach({ (key, value) in
            userInfo[key] = value
        })
        
        sound = .mixin
        categoryIdentifier = NotificationCategoryIdentifier.message
    }
    
    private func messagePreview(conversationIsGroup: Bool, isRepresentativeMessage: Bool, message: MessageItem) -> String {
        if message.category.hasSuffix("_TEXT") {
            if conversationIsGroup || isRepresentativeMessage {
                return "\(message.userFullName): \(message.content)"
            } else {
                return message.content
            }
        } else if message.category.hasSuffix("_IMAGE") {
            if conversationIsGroup || isRepresentativeMessage {
                return localized("alert_key_group_image_message", arguments: [message.userFullName])
            } else {
                return localized("alert_key_contact_image_message")
            }
        } else if message.category.hasSuffix("_VIDEO") {
            if conversationIsGroup || isRepresentativeMessage {
                return localized("alert_key_group_video_message", arguments: [message.userFullName])
            } else {
                return localized("alert_key_contact_video_message")
            }
        } else if message.category.hasSuffix("_LIVE") {
            if conversationIsGroup || isRepresentativeMessage {
                return localized("alert_key_group_live_message", arguments: [message.userFullName])
            } else {
                return localized("alert_key_contact_live_message")
            }
        } else if message.category.hasSuffix("_AUDIO") {
            if conversationIsGroup || isRepresentativeMessage {
                return localized("alert_key_group_audio_message", arguments: [message.userFullName])
            } else {
                return localized("alert_key_contact_audio_message")
            }
        } else if message.category.hasSuffix("_DATA") {
            if conversationIsGroup || isRepresentativeMessage {
                return localized("alert_key_group_data_message", arguments: [message.userFullName])
            } else {
                return localized("alert_key_contact_data_message")
            }
        } else if message.category.hasSuffix("_STICKER") {
            if conversationIsGroup || isRepresentativeMessage {
                return localized("alert_key_group_sticker_message", arguments: [message.userFullName])
            } else {
                return localized("alert_key_contact_sticker_message")
            }
        } else if message.category.hasSuffix("_CONTACT") {
            if conversationIsGroup || isRepresentativeMessage {
                return localized("alert_key_group_contact_message", arguments: [message.userFullName])
            } else {
                return localized("alert_key_contact_contact_message")
            }
        } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            switch message.snapshotType {
            case SnapshotType.deposit.rawValue:
                return localized("notification_content_deposit")
            case SnapshotType.transfer.rawValue:
                return localized("alert_key_contact_transfer_message")
            case SnapshotType.withdrawal.rawValue:
                return localized("notification_content_withdrawal")
            case SnapshotType.fee.rawValue:
                return localized("notification_content_fee")
            case SnapshotType.rebate.rawValue:
                return localized("notification_content_rebate")
            default:
                return localized("notification_content_general")
            }
        } else {
            return localized("notification_content_general")
        }
    }
    
}
