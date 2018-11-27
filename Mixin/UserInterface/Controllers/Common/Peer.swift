import Foundation

class Peer {
    
    enum Item {
        case conversation(ConversationItem)
        case user(UserItem)
    }
    
    let conversationId: String
    let item: Item
    
    var name: String {
        switch item {
        case .conversation(let conversation):
            return conversation.getConversationName()
        case .user(let user):
            return user.fullName
        }
    }
    
    var isVerified: Bool {
        switch item {
        case .conversation:
            return false
        case .user(let user):
            return user.isVerified
        }
    }
    
    var isBot: Bool {
        switch item {
        case .conversation:
            return false
        case .user(let user):
            return user.isBot
        }
    }
    
    var user: UserItem? {
        switch item {
        case .conversation:
            return nil
        case .user(let user):
            return user
        }
    }
    
    var isGroup: Bool {
        switch item {
        case .conversation(let conversation):
            return conversation.category == ConversationCategory.GROUP.rawValue
        case .user:
            return false
        }
    }
    
    init(conversation: ConversationItem) {
        self.item = .conversation(conversation)
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
                               identityNumber: user.identityNumber,
                               name: user.fullName)
        case .conversation(let conversation):
            if conversation.category == ConversationCategory.CONTACT.rawValue {
                imageView.setImage(with: conversation.ownerAvatarUrl,
                                   identityNumber: conversation.ownerIdentityNumber,
                                   name: conversation.ownerFullName)
            } else {
                imageView.setGroupImage(with: conversation.iconUrl,
                                        conversationId: conversation.conversationId)
            }
        }
    }
    
}

extension Peer: Equatable {
    
    static func == (lhs: Peer, rhs: Peer) -> Bool {
        return lhs.conversationId == rhs.conversationId
    }
    
}

extension Peer: Hashable {
    
    var hashValue: Int {
        return conversationId.hashValue
    }
    
}
