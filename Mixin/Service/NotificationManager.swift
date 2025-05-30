import Foundation
import UserNotifications
import MixinServices

final class NotificationManager: NSObject {
    
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
        getAuthorized { isAuthorized in
            self.notificationWasAuthorized = isAuthorized
            if isAuthorized {
                PushNotificationDiagnostic.global.token = .requested(Date())
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                PushNotificationDiagnostic.global.token = .unauthorized
            }
        }
    }
    
    func requestCallNotification(id: String, name: String) {
        let content = UNMutableNotificationContent()
        content.title = name
        content.body = R.string.localizable.alert_key_contact_audio_call_message()
        content.sound = .call
        content.categoryIdentifier = NotificationCategoryIdentifier.call
        let request = UNNotificationRequest(identifier: id,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func requestDeclinedCallNotification(username: String?, messageId: String) {
        let content = UNMutableNotificationContent()
        content.title = username ?? ""
        content.body = R.string.localizable.voice_call_has_been_declined()
        content.sound = .mixin
        content.categoryIdentifier = NotificationCategoryIdentifier.call
        let request = UNNotificationRequest(identifier: messageId,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func requestDeclinedGroupCallNotification(localizedName: String, messageId: String) {
        let content = UNMutableNotificationContent()
        content.title = localizedName
        content.body = R.string.localizable.group_call_has_been_declined()
        content.sound = .mixin
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
        let userInfo = notification.request.content.userInfo
        if let conversationId = userInfo[UNNotificationContent.UserInfoKey.conversationId] as? String, !conversationId.isEmpty, conversationId == UIApplication.currentConversationId() {
            completionHandler([])
            return
        }
        if let uuid = UUID(uuidString: notification.request.identifier), CallService.shared.handledUUIDs.contains(uuid) {
            completionHandler([])
            return
        }
        // TODO: Show notification muted messages with `list` only?
        completionHandler([.list, .banner, .sound])
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
        guard canProcessMessages else {
            return
        }
        if response.actionIdentifier == NotificationActionIdentifier.reply {
            guard let conversationCategory = userInfo[UNNotificationContent.UserInfoKey.conversationCategory] as? String else {
                return
            }
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
            
            SendMessageService.shared.sendReadMessages(conversationId: conversationId)
            DispatchQueue.global().async {
                SendMessageService.shared.sendMessage(message: reply,
                                                      ownerUser: ownerUser,
                                                      isGroupMessage: conversationCategory == ConversationCategory.GROUP.rawValue)
            }
        } else if let aps = userInfo["aps"] as? [String: AnyHashable?], let alert = aps["alert"] as? [String: AnyHashable?], let key = alert["loc-key"] as? String, key == "alert_key_contact_audio_call_message" {
            if !WebSocketService.shared.isConnected {
                BackgroundMessagingService.shared.end()
                MixinService.isStopProcessMessages = false
                WebSocketService.shared.connectIfNeeded()
            }
            CallService.shared.handlePendingWebRTCJobs()
        } else {
            DispatchQueue.global().async {
                guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) else {
                    return
                }
                guard conversation.status == ConversationStatus.SUCCESS.rawValue else {
                    return
                }
                DispatchQueue.main.async {
                    WebSocketService.shared.connectIfNeeded()
                    func pushConversationController() {
                        let push = {
                            let vc = ConversationViewController.instance(conversation: conversation)
                            UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
                        }
                        UIApplication.homeContainerViewController?.clipSwitcher.hideFullscreenSwitcher()
                        if var webControllers = UIApplication.homeContainerViewController?.children.compactMap({ $0 as? MixinWebViewController}), !webControllers.isEmpty {
                            let last = webControllers.removeLast()
                            for webController in webControllers {
                                webController.minimizeWithAnimation()
                            }
                            last.minimizeWithAnimation(completion: push)
                        } else {
                            push()
                        }
                    }
                    if let container = UIApplication.homeContainerViewController, container.galleryIsOnTopMost {
                        let currentItemViewController = container.galleryViewController.currentItemViewController
                        if let vc = currentItemViewController as? GalleryVideoItemViewController {
                            vc.togglePipMode(completion: {
                                DispatchQueue.main.async(execute: pushConversationController)
                            })
                        } else {
                            container.galleryViewController.dismiss(transitionViewInitialOffsetY: 0)
                            pushConversationController()
                        }
                    } else {
                        pushConversationController()
                    }
                    CallService.shared.minimizeIfThereIsAnActiveCall()
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
            let isAuthorized = [.authorized, .provisional].contains(settings.authorizationStatus)
            if isAuthorized {
                DispatchQueue.main.async {
                    PushNotificationDiagnostic.global.token = .requested(Date())
                    UIApplication.shared.registerForRemoteNotifications()
                }
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
        let silent = notification.userInfo?[MessageDAO.UserInfoKey.silentNotification] as? Bool ?? false
        guard let job = RequestInAppNotificationJob(message: message, silent: silent) else {
            return
        }
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}

// MARK: - Authorization
extension NotificationManager {
    
    func getAuthorized(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    completion(true)
                case .notDetermined, .denied:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    func getAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            getAuthorized { isAuthorized in
                continuation.resume(returning: isAuthorized)
            }
        }
    }
    
}
