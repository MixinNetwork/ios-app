import Foundation
import MixinServices

class MessageReceiver {
    
    enum Item {
        case group(ConversationItem)
        case user(UserItem)
    }
    
    let conversationId: String
    let name: String
    let badgeImage: UIImage?
    let item: Item
    
    init?(conversation: ConversationItem) {
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            let userId = conversation.ownerId
            guard !userId.isEmpty, let user = MessageReceiver.user(id: userId) else {
                return nil
            }
            name = user.fullName
            badgeImage = SearchResult.userBadgeImage(isVerified: user.isVerified, appId: user.appId)
            item = .user(user)
        } else if conversation.category == ConversationCategory.GROUP.rawValue {
            name = conversation.name
            badgeImage = nil
            item = .group(conversation)
        } else {
            return nil
        }
        conversationId = conversation.conversationId
    }
    
    init(user: UserItem) {
        name = user.fullName
        badgeImage = SearchResult.userBadgeImage(isVerified: user.isVerified, appId: user.appId)
        item = .user(user)
        conversationId = ConversationDAO.shared.makeConversationId(userId: user.userId, ownerUserId: myUserId)
    }
    
    func matches(lowercasedKeyword keyword: String) -> Bool {
        switch item {
        case let .group(conversation):
            return conversation.name.lowercased().contains(keyword)
        case let .user(user):
            return user.matches(lowercasedKeyword: keyword)
        }
    }
    
}

extension MessageReceiver: Equatable {
    
    static func == (lhs: MessageReceiver, rhs: MessageReceiver) -> Bool {
        return lhs.conversationId == rhs.conversationId
    }
    
}

extension MessageReceiver: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(conversationId)
    }
    
}

extension MessageReceiver {
    
    private static func user(id: String) -> UserItem? {
        if let user = UserDAO.shared.getUser(userId: id) {
            return user
        } else if case let .success(user) = UserAPI.shared.showUser(userId: id) {
            UserDAO.shared.updateUsers(users: [user])
            if let user = UserDAO.shared.getUser(userId: id) {
                return user
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
}
