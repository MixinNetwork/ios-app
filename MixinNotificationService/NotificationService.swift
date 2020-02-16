import UserNotifications
import MixinServices

final class NotificationService: UNNotificationServiceExtension {
    
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var rawContent: UNNotificationContent?
    private var isExpired = false
    private var conversationId: String?
    private var messageId = ""
    
    deinit {
        AppGroupUserDefaults.isProcessingMessagesInAppExtension = ReceiveMessageService.shared.isProcessingMessagesInAppExtension
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.rawContent = request.content
        self.conversationId = request.content.userInfo["conversation_id"] as? String

        guard let messageId = request.content.userInfo["message_id"] as? String, canProcessMessages else {
            deliverRawContent(from: "notification data broken")
            return
        }

        self.messageId = messageId
        _ = DarwinNotificationManager.shared
        _ = NetworkManager.shared
        MixinService.callMessageCoordinator = CallManager.shared
        ReceiveMessageService.shared.processReceiveMessage(messageId: messageId, conversationId: self.conversationId, extensionTimeWillExpire: { [weak self]() -> Bool in
            return self?.isExpired ?? true
        }) { [weak self](messageItem) in
            guard let weakSelf = self else {
                return
            }
            if let message = messageItem {
                weakSelf.deliverNotification(with: message)
            } else {
                weakSelf.deliverRawContent(from: "no message")
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        isExpired = true
        deliverRawContent(from: "serviceExtensionTimeWillExpire")
    }
    
    private func deliverNotification(with message: MessageItem) {
        guard message.status != MessageStatus.FAILED.rawValue else {
            deliverRawContent(from: "message status failed")
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: message.conversationId) else {
            deliverRawContent(from: "no conversation")
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
    
    private func deliverRawContent(from: String) {
        guard let rawContent = rawContent else {
            return
        }
        contentHandler?(rawContent)

        if let conversationId = self.conversationId {
            let websocketStatus = AppGroupUserDefaults.websocketStatusInMainApp.rawValue
            let isProcessingMessages = AppGroupUserDefaults.isProcessingMessagesInMainApp
            Logger.write(conversationId: conversationId, log: "[AppExtension][\(self.messageId)]...websocketStatusInMainApp:\(websocketStatus)]...isProcessingMessagesInMainApp:\(isProcessingMessages)...isExpired:\(isExpired)...\(from)")
        }
    }
    
}
