import Foundation
import MixinServices

extension CircleMember {
    
    convenience init(user: UserItem) {
        let conversationId = ConversationDAO.shared.makeConversationId(userId: user.userId, ownerUserId: myUserId)
        let badgeImage = SearchResult.userBadgeImage(isVerified: user.isVerified, appId: user.appId)
        self.init(conversationId: conversationId,
                  userId: user.userId,
                  category: ConversationCategory.CONTACT.rawValue,
                  name: user.fullName,
                  iconUrl: user.avatarUrl,
                  identityNumber: user.identityNumber,
                  phoneNumber: user.phone,
                  badgeImage: badgeImage)
    }
    
    convenience init(conversation: ConversationItem) {
        let isGroup = conversation.category == ConversationCategory.GROUP.rawValue
        self.init(conversationId: conversation.conversationId,
                  userId: conversation.ownerId,
                  category: conversation.category ?? ConversationCategory.CONTACT.rawValue,
                  name: conversation.getConversationName(),
                  iconUrl: isGroup ? conversation.iconUrl : conversation.ownerAvatarUrl,
                  identityNumber: conversation.ownerIdentityNumber,
                  phoneNumber: nil,
                  badgeImage: nil)
    }
    
}
