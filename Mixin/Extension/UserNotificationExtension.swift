import Foundation
import UserNotifications
import UIKit

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
        let textAction = UNTextInputNotificationAction(identifier: NotificationIdentifier.replyAction.rawValue,
                                                       title: Localized.NOTIFICATION_REPLY,
                                                       options: [])
        let category = UNNotificationCategory(identifier: NotificationIdentifier.actionCategory.rawValue,
                                              actions: [textAction],
                                              intentIdentifiers: [NotificationIdentifier.replyAction.rawValue],
                                              options: [])

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func sendMessageNotification(message: MessageItem, ownerUser: UserItem?, conversation: ConversationItem) {
        let notificationContent = UNMutableNotificationContent()
        if conversation.isGroup() {
            notificationContent.title = conversation.name
        } else {
            notificationContent.title = message.userFullName
        }

        if message.category.hasSuffix("_TEXT") {
            if conversation.isGroup() {
                notificationContent.body = "\(message.userFullName): \(message.content)"
            } else {
                notificationContent.body = message.content
            }
        } else if message.category.hasSuffix("_IMAGE") {
            if conversation.isGroup() {
                notificationContent.body = "\(message.userFullName): \(Localized.NOTIFICATION_CONTENT_PHOTO)"
            } else {
                notificationContent.body = Localized.NOTIFICATION_CONTENT_PHOTO
            }
        } else if message.category.hasSuffix("_VIDEO") {
            if conversation.isGroup() {
                notificationContent.body = "\(message.userFullName): \(Localized.NOTIFICATION_CONTENT_VIDEO)"
            } else {
                notificationContent.body = Localized.NOTIFICATION_CONTENT_VIDEO
            }
        } else if message.category.hasSuffix("_DATA") {
            if conversation.isGroup() {
                notificationContent.body = "\(message.userFullName): \(Localized.NOTIFICATION_CONTENT_FILE)"
            } else {
                notificationContent.body = Localized.NOTIFICATION_CONTENT_FILE
            }
        } else if message.category.hasSuffix("_STICKER") {
            if conversation.isGroup() {
                notificationContent.body = "\(message.userFullName): \(Localized.NOTIFICATION_CONTENT_STICKER)"
            } else {
                notificationContent.body = Localized.NOTIFICATION_CONTENT_STICKER
            }
        } else if message.category.hasSuffix("_CONTACT") {
            if conversation.isGroup() {
                notificationContent.body = "\(message.userFullName): \(Localized.NOTIFICATION_CONTENT_CONTACT)"
            } else {
                notificationContent.body = Localized.NOTIFICATION_CONTENT_CONTACT
            }
        } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            switch message.snapshotType {
            case SnapshotType.deposit.rawValue:
                notificationContent.body = Localized.NOTIFICATION_CONTENT_DEPOSIT
            case SnapshotType.transfer.rawValue:
                notificationContent.body = Localized.NOTIFICATION_CONTENT_TRANSFER
            case SnapshotType.withdrawal.rawValue:
                notificationContent.body = Localized.NOTIFICATION_CONTENT_WITHDRAWAL
            case SnapshotType.fee.rawValue:
                notificationContent.body = Localized.NOTIFICATION_CONTENT_FEE
            case SnapshotType.rebate.rawValue:
                notificationContent.body = Localized.NOTIFICATION_CONTENT_REBATE
            default:
                return
            }
        } else {
            return
        }

        var userInfo = [String: Any]()
        userInfo["fromWebSocket"] = true
        userInfo["conversation_id"] = message.conversationId
        userInfo["user_id"] = message.userId
        userInfo["message_id"] = message.messageId
        userInfo["conversation_category"] = conversation.category
        if let user = ownerUser {
            userInfo["userFullName"] = user.fullName
            userInfo["userAvatarUrl"] = user.avatarUrl
            userInfo["userIdentityNumber"] = user.identityNumber
        }
        notificationContent.userInfo = userInfo
        notificationContent.sound = UNNotificationSound(named: "mixin.caf")
        notificationContent.categoryIdentifier = NotificationIdentifier.actionCategory.rawValue

        if UIApplication.shared.applicationState == .active {
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: NotificationIdentifier.showInAppNotification.rawValue, content: notificationContent, trigger: nil), withCompletionHandler: nil)
        } else {
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: message.messageId, content: notificationContent, trigger: nil), withCompletionHandler: nil)
        }
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

