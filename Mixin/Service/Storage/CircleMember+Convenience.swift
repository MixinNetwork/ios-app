import Foundation
import MixinServices

extension CircleMember {
    
    convenience init(user: UserItem) {
        let conversationId = ConversationDAO.shared.makeConversationId(userId: user.userId, ownerUserId: myUserId)
        let badgeImage = SearchResult.userBadgeImage(isVerified: user.isVerified, appId: user.appId)
        self.init(conversationId: conversationId,
                  ownerId: user.userId,
                  category: ConversationCategory.CONTACT.rawValue,
                  name: user.fullName,
                  iconUrl: user.avatarUrl,
                  badgeImage: badgeImage)
    }
    
    convenience init(conversation: ConversationItem) {
        self.init(conversationId: conversation.conversationId,
                  ownerId: conversation.ownerId,
                  category: conversation.category ?? ConversationCategory.CONTACT.rawValue,
                  name: conversation.getConversationName(),
                  iconUrl: conversation.iconUrl,
                  badgeImage: nil)
    }
    
}
