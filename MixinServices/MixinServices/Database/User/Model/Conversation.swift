import Foundation
import GRDB

public enum ConversationCategory: String {
    case CONTACT = "CONTACT"
    case GROUP = "GROUP"
}

public enum ConversationStatus: Int {
    case START = 0
    case SUCCESS = 1
    case QUIT = 2
}

public struct Conversation {
    
    public let conversationId: String
    public var ownerId: String?
    public var category: String?
    public var name: String?
    public var iconUrl: String?
    public var announcement: String?
    public var lastMessageId: String?
    public var lastMessageCreatedAt: String?
    public var lastReadMessageId: String?
    public var unseenMessageCount: Int?
    public var status: Int
    public var draft: String?
    public var muteUntil: String?
    public var codeUrl: String?
    public var pinTime: String?
    public var expireIn: Int64?
    
    public init(conversationId: String, ownerId: String? = nil, category: String? = nil, name: String? = nil, iconUrl: String? = nil, announcement: String? = nil, lastMessageId: String? = nil, lastMessageCreatedAt: String? = nil, lastReadMessageId: String? = nil, unseenMessageCount: Int? = nil, status: Int, draft: String? = nil, muteUntil: String? = nil, codeUrl: String? = nil, pinTime: String? = nil, expireIn: Int64? = nil) {
        self.conversationId = conversationId
        self.ownerId = ownerId
        self.category = category
        self.name = name
        self.iconUrl = iconUrl
        self.announcement = announcement
        self.lastMessageId = lastMessageId
        self.lastMessageCreatedAt = lastMessageCreatedAt
        self.lastReadMessageId = lastReadMessageId
        self.unseenMessageCount = unseenMessageCount
        self.status = status
        self.draft = draft
        self.muteUntil = muteUntil
        self.codeUrl = codeUrl
        self.pinTime = pinTime
        self.expireIn = expireIn
    }
    
    public static func createConversation(from conversation: ConversationResponse, ownerId: String, status: ConversationStatus) -> Conversation {
        return Conversation(conversationId: conversation.conversationId, ownerId: ownerId, category: conversation.category, name: conversation.name, iconUrl: conversation.iconUrl, announcement: conversation.announcement, lastMessageId: nil, lastMessageCreatedAt: nil, lastReadMessageId: nil, unseenMessageCount: 0, status: status.rawValue, draft: nil, muteUntil: conversation.muteUntil, codeUrl: conversation.codeUrl, pinTime: nil, expireIn: 0)
    }

    public static func createConversation(conversationId: String, category: String?, recipientId: String, status: Int) -> Conversation {
        return Conversation(conversationId: conversationId, ownerId: recipientId, category: category, name: nil, iconUrl: nil, announcement: nil, lastMessageId: nil, lastMessageCreatedAt: nil, lastReadMessageId: nil, unseenMessageCount: 0, status: status, draft: nil, muteUntil: nil, codeUrl: nil, pinTime: nil, expireIn: 0)
    }
    
    public func isGroup() -> Bool {
        return category == ConversationCategory.GROUP.rawValue
    }
    
}

extension Conversation: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case ownerId = "owner_id"
        case category
        case name
        case iconUrl = "icon_url"
        case announcement
        case lastMessageId = "last_message_id"
        case lastMessageCreatedAt = "last_message_created_at"
        case lastReadMessageId = "last_read_message_id"
        case unseenMessageCount = "unseen_message_count"
        case status
        case draft
        case muteUntil = "mute_until"
        case codeUrl = "code_url"
        case pinTime = "pin_time"
        case expireIn = "expire_in"
    }
    
}

extension Conversation: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "conversations"
    
}
