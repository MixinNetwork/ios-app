import Foundation
import WCDBSwift

struct Conversation: BaseCodable {

    static var tableName: String = "conversations"

    let conversationId: String
    var ownerId: String? = nil
    var category: String? = nil
    var name: String? = nil
    var iconUrl: String? = nil
    var announcement: String? = nil
    var lastMessageId: String? = nil
    var lastMessageCreatedAt: String? = nil
    var lastReadMessageId: String? = nil
    var unseenMessageCount: Int? = nil
    var status: Int
    var draft: String? = nil
    var muteUntil: String? = nil
    var codeUrl: String? = nil
    var pinTime: String? = nil

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Conversation
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

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                conversationId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_indexs": IndexBinding(indexesBy: [pinTime, lastMessageCreatedAt])
            ]
        }
    }

    static func createConversation(from conversation: ConversationResponse, ownerId: String, status: ConversationStatus) -> Conversation {
        return Conversation(conversationId: conversation.conversationId, ownerId: ownerId, category: conversation.category, name: conversation.name, iconUrl: conversation.iconUrl, announcement: conversation.announcement, lastMessageId: nil, lastMessageCreatedAt: Date().toUTCString(), lastReadMessageId: nil, unseenMessageCount: 0, status: status.rawValue, draft: nil, muteUntil: conversation.muteUntil, codeUrl: conversation.codeUrl, pinTime: nil)
    }

    static func createConversation(conversationId: String, category: String?, recipientId: String, status: Int) -> Conversation {
        return Conversation(conversationId: conversationId, ownerId: recipientId, category: category, name: nil, iconUrl: nil, announcement: nil, lastMessageId: nil, lastMessageCreatedAt: Date().toUTCString(), lastReadMessageId: nil, unseenMessageCount: 0, status: status, draft: nil, muteUntil: nil, codeUrl: nil, pinTime: nil)
    }
}

extension Conversation {
    func isGroup() -> Bool {
        return category == ConversationCategory.GROUP.rawValue
    }
}

enum ConversationCategory: String {
    case CONTACT = "CONTACT"
    case GROUP = "GROUP"
}

enum ConversationStatus: Int {
    case START = 0
    case SUCCESS = 1
    case QUIT = 2
}
