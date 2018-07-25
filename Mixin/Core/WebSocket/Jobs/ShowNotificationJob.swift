import Foundation
import UserNotifications
import UIKit

class ShowNotificationJob: BaseJob {

    let messageId: String

    init(messageId: String) {
        self.messageId = messageId
    }

    override func getJobId() -> String {
        return "show-notification-\(messageId)"
    }

    override func main() {
        guard !isCancelled, let message = MessageDAO.shared.getFullMessage(messageId: messageId) else {
            return
        }
        guard message.status == MessageStatus.DELIVERED.rawValue, message.userId != currentAccountId else {
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

        DispatchQueue.main.async {
            guard message.conversationId != UIApplication.currentConversationId() else {
                return
            }

            UNUserNotificationCenter.current().sendMessageNotification(message: message, ownerUser: ownerUser, conversation: conversation)
        }
    }

}
