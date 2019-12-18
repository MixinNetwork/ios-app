import Foundation
import UserNotifications
import UIKit

class RequestInAppNotificationJob: BaseJob {
    
    let message: MessageItem
    
    init?(message: MessageItem) {
        guard message.status == MessageStatus.DELIVERED.rawValue else {
            return nil
        }
        guard message.userId != AccountAPI.shared.accountUserId else {
            return nil
        }
        let availableCategorySuffices = ["_TEXT", "_IMAGE", "_STICKER", "_CONTACT", "_DATA", "_VIDEO", "_LIVE", "_AUDIO"]
        let isCategoryAvailable = availableCategorySuffices.contains(where: message.category.hasSuffix(_:))
            || message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue
        guard isCategoryAvailable else {
            return nil
        }
        self.message = message
    }
    
    override func getJobId() -> String {
        return "show-notification-\(message.messageId)"
    }
    
    override func main() {
        let message = self.message
        guard !isCancelled else {
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: message.conversationId), conversation.status == ConversationStatus.SUCCESS.rawValue, !conversation.isMuted else {
            return
        }
        
        var ownerUser: UserItem?
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            guard let user = UserDAO.shared.getUser(userId: message.userId) else {
                return
            }
            if AccountAPI.shared.account?.receive_message_source == ReceiveMessageSource.contacts.rawValue && user.relationship != Relationship.FRIEND.rawValue {
                return
            }
            ownerUser = user
        }
        
        DispatchQueue.main.sync {
            ConversationDAO.shared.showBadgeNumber()
            let content = UNMutableNotificationContent(message: message, ownerUser: ownerUser, conversation: conversation)
            let request = UNNotificationRequest(identifier: message.messageId, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
    
}
