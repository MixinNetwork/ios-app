import Foundation
import UserNotifications
import UIKit

class ShowNotificationJob: BaseJob {

    let message: MessageItem

    init(message: MessageItem) {
        self.message = message
    }

    override func getJobId() -> String {
        return "show-notification-\(message.messageId)"
    }

    override func main() {
        let message = self.message
        guard !isCancelled, message.status == MessageStatus.DELIVERED.rawValue, message.userId != currentAccountId else {
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

            DispatchQueue.global().async {
                var badgeNumber = ConversationDAO.shared.getBadgeNumber()
                if badgeNumber > 99 {
                    badgeNumber = 99
                }

                DispatchQueue.main.async {
                    if badgeNumber != UIApplication.shared.applicationIconBadgeNumber {
                        UIApplication.shared.applicationIconBadgeNumber = badgeNumber
                    }
                }
            }

            ConversationDAO.shared.getBadgeNumber()
            UNUserNotificationCenter.current().sendMessageNotification(message: message, ownerUser: ownerUser, conversation: conversation)
        }
    }

}
