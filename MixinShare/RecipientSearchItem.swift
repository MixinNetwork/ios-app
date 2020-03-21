import Foundation
import MixinServices

class RecipientSearchItem {

    let conversationId: String
    let name: String
    let userId: String
    let avatarUrl: String
    let iconUrl: String
    let category: String
    let isBot : Bool
    let isVerified : Bool
    let identityNumber: String
    let phoneNumber: String

    init?(conversation: ConversationItem) {
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            name = conversation.ownerFullName
            identityNumber = conversation.ownerIdentityNumber
        } else if conversation.category == ConversationCategory.GROUP.rawValue {
            name = conversation.name
            identityNumber = ""
        } else {
            return nil
        }
        category = conversation.category ?? ""
        iconUrl = conversation.iconUrl
        userId = conversation.ownerId
        avatarUrl = conversation.ownerAvatarUrl
        conversationId = conversation.conversationId
        isBot = conversation.ownerIsBot
        isVerified = conversation.ownerIsVerified
        phoneNumber = ""
    }

    init(user: UserItem) {
        conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: user.userId)
        name = user.fullName
        category = ConversationCategory.CONTACT.rawValue
        iconUrl = ""
        userId = user.userId
        avatarUrl = user.avatarUrl
        isBot = user.isBot
        isVerified = user.isVerified
        identityNumber = user.identityNumber
        phoneNumber = user.phone ?? ""
    }

    func matches(lowercasedKeyword keyword: String) -> Bool {
        return name.lowercased().contains(keyword) || phoneNumber.contains(keyword) || identityNumber.contains(keyword)
    }

    var isSignalConversation: Bool {
        category == ConversationCategory.GROUP.rawValue || (category == ConversationCategory.CONTACT.rawValue && !isBot)
    }
}

extension RecipientSearchItem: Equatable {

    static func == (lhs: RecipientSearchItem, rhs: RecipientSearchItem) -> Bool {
        return lhs.conversationId == rhs.conversationId
    }

}

extension RecipientSearchItem: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(conversationId)
    }

}
