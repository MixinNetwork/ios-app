import UserNotifications
import MixinServices

final class NotificationService: UNNotificationServiceExtension {
    
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var rawContent: UNNotificationContent?
    private var isExpired = false
    
    deinit {
        AppGroupUserDefaults.isProcessingMessagesInAppExtension = ReceiveMessageService.shared.isProcessingMessagesInAppExtension
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.rawContent = request.content

        guard let messageId = request.content.userInfo["message_id"] as? String, canProcessMessages else {
            deliverRawContent()
            return
        }

        _ = DarwinNotificationManager.shared
        _ = NetworkManager.shared
        MixinService.callMessageCoordinator = CallManager.shared
        ReceiveMessageService.shared.processReceiveMessage(messageId: messageId, extensionTimeWillExpire: { [weak self]() -> Bool in
            return self?.isExpired ?? true
        }) { [weak self](messageItem) in
            guard let weakSelf = self else {
                return
            }
            if let message = messageItem {
                weakSelf.deliverNotification(with: message)
            } else {
                weakSelf.deliverRawContent()
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        isExpired = true
        deliverRawContent()
    }
    
    private func deliverNotification(with message: MessageItem) {
        guard message.status != MessageStatus.FAILED.rawValue else {
            deliverRawContent()
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: message.conversationId) else {
            deliverRawContent()
            return
        }
        let ownerUser: UserItem?
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            ownerUser = UserDAO.shared.getUser(userId: message.userId)
        } else {
            ownerUser = nil
        }
        let content = UNMutableNotificationContent(message: message, ownerUser: ownerUser, conversation: conversation)
        contentHandler?(content)
    }
    
    private func deliverRawContent() {
        guard let rawContent = rawContent else {
            return
        }
        contentHandler?(rawContent)
    }
    
}
