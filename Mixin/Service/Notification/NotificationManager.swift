import Foundation
import UserNotifications

class NotificationManager: NSObject {
    
    static let shared = NotificationManager()
    
    private var notificationWasAuthorized: Bool?
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(requestInAppNotification(_:)), name: MessageDAO.didInsertMessageNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(requestInAppNotification(_:)), name: MessageDAO.didRedecryptMessageNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func registerForRemoteNotificationsIfAuthorized() {
        requestAuthorization { (isAuthorized) in
            self.notificationWasAuthorized = isAuthorized
            if isAuthorized {
                DispatchQueue.main.async(execute: UIApplication.shared.registerForRemoteNotifications)
            }
        }
    }
    
    func requestCallNotification(messageId: String, callerName: String) {
        let content = UNMutableNotificationContent()
        content.title = callerName
        content.body = Localized.ALERT_KEY_CONTACT_AUDIO_CALL_MESSAGE
        content.sound = .call
        content.categoryIdentifier = NotificationCategoryIdentifier.call
        let request = UNNotificationRequest(identifier: messageId,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard notification.request.identifier != UIApplication.currentConversationId() else {
            completionHandler([])
            return
        }
        completionHandler([.alert, .sound])
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            center.removeNotifications(withIdentifiers: [notification.request.identifier])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        defer {
            completionHandler()
        }
        let userInfo = response.notification.request.content.userInfo
        guard let conversationId = userInfo[UNNotificationContent.UserInfoKey.conversationId] as? String else {
            return
        }
        guard let conversationCategory = userInfo[UNNotificationContent.UserInfoKey.conversationCategory] as? String else {
            return
        }
        if response.actionIdentifier == NotificationActionIdentifier.reply {
            guard let messageId = userInfo[UNNotificationContent.UserInfoKey.messageId] as? String else {
                return
            }
            guard let userText = (response as? UNTextInputNotificationResponse)?.userText else {
                return
            }
            let ownerUser = UserItem.makeUserItem(notificationUserInfo: userInfo)
            let trimmedUserText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUserText.isEmpty else {
                return
            }
            var reply = Message.createMessage(category: MessageCategory.SIGNAL_TEXT.rawValue,
                                              conversationId: conversationId,
                                              userId: myUserId)
            reply.content = trimmedUserText
            reply.quoteMessageId = messageId
            DispatchQueue.global().async {
                SendMessageService.shared.sendReadMessages(conversationId: conversationId)
                SendMessageService.shared.sendMessage(message: reply,
                                                      ownerUser: ownerUser,
                                                      isGroupMessage: conversationCategory == ConversationCategory.GROUP.rawValue)
            }
        } else {
            DispatchQueue.global().async {
                guard LoginManager.shared.isLoggedIn else {
                    return
                }
                guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) else {
                    return
                }
                guard conversation.status == ConversationStatus.SUCCESS.rawValue else {
                    return
                }
                DispatchQueue.main.async {
                    let vc = ConversationViewController.instance(conversation: conversation)
                    UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
                }
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        
    }
    
}

// MARK: - Callback
extension NotificationManager {
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        UNUserNotificationCenter.current().removeAllNotifications()
        guard let notificationWasAuthorized = notificationWasAuthorized, !notificationWasAuthorized else {
            return
        }
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            let isAuthorized: Bool
            if #available(iOS 12.0, *) {
                isAuthorized = [.authorized, .provisional].contains(settings.authorizationStatus)
            } else {
                isAuthorized = .authorized == settings.authorizationStatus
            }
            if isAuthorized {
                DispatchQueue.main.async(execute: UIApplication.shared.registerForRemoteNotifications)
            }
        }
    }
    
    @objc private func requestInAppNotification(_ notification: Notification) {
        guard let message = notification.userInfo?[MessageDAO.UserInfoKey.message] as? MessageItem else {
            return
        }
        guard let source = notification.userInfo?[MessageDAO.UserInfoKey.messsageSource] as? String else {
            return
        }
        guard source != BlazeMessageAction.listPendingMessages.rawValue || abs(message.createdAt.toUTCDate().timeIntervalSinceNow) < 60 else {
            return
        }
        guard let job = RequestInAppNotificationJob(message: message) else {
            return
        }
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}

// MARK: - Private works
extension NotificationManager {
    
    private func requestAuthorization(completion: @escaping (_ isAuthorized: Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { (settings) in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { (isGranted, _) in
                    completion(isGranted)
                }
            case .denied:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }
    
}
