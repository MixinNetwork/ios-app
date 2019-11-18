import Foundation
import UserNotifications
import UIKit

extension UNNotificationSound {
    
    static let mixin = UNNotificationSound(named: UNNotificationSoundName("mixin.caf"))
    static let call = UNNotificationSound(named: UNNotificationSoundName("call.caf"))

}

extension UNUserNotificationCenter {

    func checkNotificationSettings(completionHandler: @escaping (_ authorizationStatus: UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (setting: UNNotificationSettings) in
            DispatchQueue.main.async {
                completionHandler(setting.authorizationStatus)
            }
        })
    }

    func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings: UNNotificationSettings) in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: { (granted: Bool, error: Error?) in
                    guard granted else {
                        return
                    }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                })
            } else if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        })
    }

}

extension UNUserNotificationCenter {

    func registerNotificationCategory() {
        let textAction = UNTextInputNotificationAction(identifier: NotificationActionIdentifier.reply,
                                                       title: Localized.NOTIFICATION_REPLY,
                                                       options: [])
        let category = UNNotificationCategory(identifier: NotificationCategoryIdentifier.message,
                                              actions: [textAction],
                                              intentIdentifiers: [NotificationActionIdentifier.reply],
                                              options: [])

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func sendMessageNotification(message: MessageItem, ownerUser: UserItem?, conversation: ConversationItem) {
        let notificationContent = UNMutableNotificationContent()
        if AppGroupUserDefaults.User.showMessagePreviewInNotification {
            if !notificationContent.setTitleAndBody(with: message, ownerUser: ownerUser, conversation: conversation) {
                return
            }
        } else {
            notificationContent.body = Localized.NOTIFICATION_CONTENT_GENERAL
        }

        var userInfo = [String: Any]()
        userInfo["fromWebSocket"] = true
        userInfo["conversation_id"] = message.conversationId
        userInfo["user_id"] = message.userId
        userInfo["message_id"] = message.messageId
        userInfo["conversation_category"] = conversation.category
        if let user = ownerUser {
            userInfo["userFullName"] = user.fullName
            userInfo["userBiography"] = user.biography
            userInfo["userAvatarUrl"] = user.avatarUrl
            userInfo["userIdentityNumber"] = user.identityNumber
            userInfo["userAppId"] = user.appId
        }
        notificationContent.userInfo = userInfo
        notificationContent.sound = .mixin
        notificationContent.categoryIdentifier = NotificationCategoryIdentifier.message

        if UIApplication.shared.applicationState == .active {
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: NotificationRequestIdentifier.showInApp, content: notificationContent, trigger: nil), withCompletionHandler: nil)
        } else {
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: message.messageId, content: notificationContent, trigger: nil), withCompletionHandler: nil)
        }
    }
    
    func sendCallNotification(callerName: String) {
        let content = UNMutableNotificationContent()
        content.title = callerName
        content.body = Localized.ALERT_KEY_CONTACT_AUDIO_CALL_MESSAGE
        content.sound = .call
        content.categoryIdentifier = NotificationCategoryIdentifier.call
        let request = UNNotificationRequest(identifier: NotificationRequestIdentifier.call,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func removeNotifications(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}


extension UNTextInputNotificationAction {

    static let identifierReplyAction = "identifier_reply_action"

    static let identifierMuteAction = "identifier_mute_action"

}

fileprivate extension UNMutableNotificationContent {
    
    // Return true if success, false if not
    func setTitleAndBody(with message: MessageItem, ownerUser: UserItem?, conversation: ConversationItem) -> Bool {
        let isRepresentativeMessage = message.isRepresentativeMessage(conversation: conversation)
        if conversation.isGroup() {
            title = conversation.name
        } else if isRepresentativeMessage {
            title = conversation.ownerFullName
        } else {
            title = message.userFullName
        }
        
        if message.category.hasSuffix("_TEXT") {
            if conversation.isGroup() || isRepresentativeMessage {
                body = "\(message.userFullName): \(message.content)"
            } else {
                body = message.content
            }
        } else if message.category.hasSuffix("_IMAGE") {
            if conversation.isGroup() || isRepresentativeMessage {
                body = Localized.ALERT_KEY_GROUP_IMAGE_MESSAGE(fullname: message.userFullName)
            } else {
                body = Localized.ALERT_KEY_CONTACT_IMAGE_MESSAGE
            }
        } else if message.category.hasSuffix("_VIDEO") {
            if conversation.isGroup() || isRepresentativeMessage {
                body = Localized.ALERT_KEY_GROUP_VIDEO_MESSAGE(fullname: message.userFullName)
            } else {
                body = Localized.ALERT_KEY_CONTACT_VIDEO_MESSAGE
            }
        } else if message.category.hasSuffix("_LIVE") {
            if conversation.isGroup() || isRepresentativeMessage {
                body = R.string.localizable.alert_key_group_live_message(message.userFullName)
            } else {
                body = R.string.localizable.alert_key_contact_live_message()
            }
        } else if message.category.hasSuffix("_AUDIO") {
            if conversation.isGroup() || isRepresentativeMessage {
                body = Localized.ALERT_KEY_GROUP_AUDIO_MESSAGE(fullname: message.userFullName)
            } else {
                body = Localized.ALERT_KEY_CONTACT_AUDIO_MESSAGE
            }
        } else if message.category.hasSuffix("_DATA") {
            if conversation.isGroup() || isRepresentativeMessage {
                body = Localized.ALERT_KEY_GROUP_DATA_MESSAGE(fullname: message.userFullName)
            } else {
                body = Localized.ALERT_KEY_CONTACT_DATA_MESSAGE
            }
        } else if message.category.hasSuffix("_STICKER") {
            if conversation.isGroup() || isRepresentativeMessage {
                body = Localized.ALERT_KEY_GROUP_STICKER_MESSAGE(fullname: message.userFullName)
            } else {
                body = Localized.ALERT_KEY_CONTACT_STICKER_MESSAGE
            }
        } else if message.category.hasSuffix("_CONTACT") {
            if conversation.isGroup() || isRepresentativeMessage {
                body = Localized.ALERT_KEY_GROUP_CONTACT_MESSAGE(fullname: message.userFullName)
            } else {
                body = Localized.ALERT_KEY_CONTACT_CONTACT_MESSAGE
            }
        } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            switch message.snapshotType {
            case SnapshotType.deposit.rawValue:
                body = Localized.NOTIFICATION_CONTENT_DEPOSIT
            case SnapshotType.transfer.rawValue:
                body = Localized.ALERT_KEY_CONTACT_TRANSFER_MESSAGE
            case SnapshotType.withdrawal.rawValue:
                body = Localized.NOTIFICATION_CONTENT_WITHDRAWAL
            case SnapshotType.fee.rawValue:
                body = Localized.NOTIFICATION_CONTENT_FEE
            case SnapshotType.rebate.rawValue:
                body = Localized.NOTIFICATION_CONTENT_REBATE
            default:
                return false
            }
        } else {
            return false
        }
        return true
    }
    
}
