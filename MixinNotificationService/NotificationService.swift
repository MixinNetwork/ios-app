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

        guard let messageId = request.content.userInfo["message_id"] as? String, canProcessMessages else {
            deliverRawContent()
            return
        }

        MixinService.callMessageCoordinator = CallManager.shared
        ReceiveMessageService.shared.processReceiveMessage(messageId: messageId) { [weak self](messageItem: MessageItem?) in
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
