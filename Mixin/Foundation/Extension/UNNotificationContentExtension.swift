import Foundation
import UserNotifications

extension UNNotificationContent {
    
    enum UserInfoKey {
        static let conversationId = "mixin_conv_id"
        static let conversationCategory = "mixin_conv_catg"
        static let messageId = "mixin_msg_id"
        static let ownerUserId = "mixin_usr_id"
        static let ownerUserFullname = "mixin_usr_name"
        static let ownerUserIdentityNumber = "mixin_usr_idnum"
        static let ownerUserAvatarUrl = "mixin_usr_avtr"
        static let ownerUserAppId = "mixin_usr_app_id"
    }
    
}

extension UserItem {
    
    var notificationUserInfo: [String: String] {
        var userInfo = [
            UNNotificationContent.UserInfoKey.ownerUserId: userId,
            UNNotificationContent.UserInfoKey.ownerUserFullname: fullName,
            UNNotificationContent.UserInfoKey.ownerUserIdentityNumber: identityNumber,
            UNNotificationContent.UserInfoKey.ownerUserAvatarUrl: avatarUrl,
        ]
        userInfo[UNNotificationContent.UserInfoKey.ownerUserAppId] = appId
        return userInfo
    }
    
    static func makeUserItem(notificationUserInfo userInfo: [AnyHashable: Any]) -> UserItem? {
        guard let userId = userInfo[UNNotificationContent.UserInfoKey.ownerUserId] as? String else {
            return nil
        }
        guard let fullName = userInfo[UNNotificationContent.UserInfoKey.ownerUserFullname] as? String else {
            return nil
        }
        guard let identityNumber = userInfo[UNNotificationContent.UserInfoKey.ownerUserIdentityNumber] as? String else {
            return nil
        }
        guard let avatarUrl = userInfo[UNNotificationContent.UserInfoKey.ownerUserAvatarUrl] as? String else {
            return nil
        }
        let appId = userInfo[UNNotificationContent.UserInfoKey.ownerUserAppId] as? String
        return UserItem.createUser(userId: userId, fullName: fullName, identityNumber: identityNumber, avatarUrl: avatarUrl, appId: appId)
    }
    
}

extension UNMutableNotificationContent {
    
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
    }
    
}

extension UNMutableNotificationContent {
    
    private func messagePreview(conversationIsGroup: Bool, isRepresentativeMessage: Bool, message: MessageItem) -> String {
        if message.category.hasSuffix("_TEXT") {
            if conversationIsGroup || isRepresentativeMessage {
                return "\(message.userFullName): \(message.content)"
            } else {
                return message.content
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
                return R.string.localizable.alert_key_group_live_message(message.userFullName)
            } else {
                return R.string.localizable.alert_key_contact_live_message()
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
        } else {
            return Localized.NOTIFICATION_CONTENT_GENERAL
        }
    }
    
}
