import Foundation

class Peer {
    
    enum Item {
        case group(ConversationItem)
        case user(UserItem)
    }
    
    let conversationId: String
    let item: Item
    
    var name: String {
        switch item {
        case .group(let conversation):
            return conversation.getConversationName()
        case .user(let user):
            return user.fullName
        }
    }
    
    var isVerified: Bool {
        switch item {
        case .group:
            return false
        case .user(let user):
            return user.isVerified
        }
    }
    
    var isBot: Bool {
        switch item {
        case .group:
            return false
        case .user(let user):
            return user.isBot
        }
    }
    
    var user: UserItem? {
        switch item {
        case .group:
            return nil
        case .user(let user):
            return user
        }
    }
    
    var isGroup: Bool {
        switch item {
        case .group:
            return true
        case .user:
            return false
        }
    }
    
    init?(conversation: ConversationItem) {
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            let userId = conversation.ownerId
            guard !userId.isEmpty else {
                return nil
            }
            if let user = UserDAO.shared.getUser(userId: userId) {
                self.item = .user(user)
            } else if case let .success(user) = UserAPI.shared.showUser(userId: userId) {
                UserDAO.shared.updateUsers(users: [user])
                if let user = UserDAO.shared.getUser(userId: userId) {
                    self.item = .user(user)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        } else if conversation.category == ConversationCategory.GROUP.rawValue {
            self.item = .group(conversation)
        } else {
            return nil
        }
        self.conversationId = conversation.conversationId
    }
    
    init(user: UserItem) {
        self.item = .user(user)
        self.conversationId = ConversationDAO.shared.makeConversationId(userId: user.userId, ownerUserId: AccountAPI.shared.accountUserId)
    }
    
    func setIconImage(to imageView: AvatarImageView) {
        switch item {
        case .user(let user):
            imageView.setImage(with: user.avatarUrl,
                               userId: user.userId,
                               name: user.fullName)
        case .group(let conversation):
            imageView.setGroupImage(with: conversation.iconUrl)
        }
    }
    
}

extension Peer: Equatable {
    
    static func == (lhs: Peer, rhs: Peer) -> Bool {
        return lhs.conversationId == rhs.conversationId
    }
    
}

extension Peer: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(conversationId)
    }
    
}
