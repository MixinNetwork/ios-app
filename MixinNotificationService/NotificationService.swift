import UserNotifications
import MixinServices

final class NotificationService: UNNotificationServiceExtension {
    
    private let timeLimit: TimeInterval = 25
    private let startDate = Date()
    
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var rawContent: UNNotificationContent?
    private var messageId: String?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.rawContent = request.content
        
        guard LoginManager.shared.isLoggedIn, AppGroupUserDefaults.isDocumentsMigrated, !AppGroupUserDefaults.User.needsUpgradeInMainApp else {
            deliverRawContent()
            return
        }
        guard let messageId = request.content.userInfo["message_id"] as? String else {
            deliverRawContent()
            return
        }
        
        self.messageId = messageId
        
        if let message = MessageDAO.shared.getFullMessage(messageId: messageId) {
            deliverNotification(with: message)
        } else {
            MixinService.callMessageCoordinator = CallManager.shared
            ReceiveMessageService.shared.delegate = self
            NotificationCenter.default.addObserver(self, selector: #selector(didInsertMessage(_:)), name: MessageDAO.didInsertMessageNotification, object: nil)
            WebSocketService.shared.connect()
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        deliverRawContent()
    }
    
    @objc private func didInsertMessage(_ notification: Notification) {
        guard let message = notification.userInfo?[MessageDAO.UserInfoKey.message] as? MessageItem else {
            return
        }
        guard message.messageId == messageId else {
            return
        }
        deliverNotification(with: message)
        NotificationCenter.default.removeObserver(self)
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

extension NotificationService: ReceiveMessageServiceDelegate {
    
    func receiveMessageService(_ service: ReceiveMessageService, shouldContinueProcessingAfterProcessingMessageWithId id: String) -> Bool {
        if messageId == id || -startDate.timeIntervalSinceNow >= timeLimit {
            WebSocketService.shared.disconnect()
            return true
        } else {
            return false
        }
    }
    
}
