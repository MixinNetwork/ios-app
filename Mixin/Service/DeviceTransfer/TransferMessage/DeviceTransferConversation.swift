import Foundation
import MixinServices

struct DeviceTransferConversation {
    
    let conversationId: String
    let ownerId: String?
    let category: String?
    let name: String?
    let announcement: String?
    let lastMessageId: String?
    let lastMessageCreatedAt: String?
    let lastReadMessageId: String?
    let unseenMessageCount: Int?
    let status: Int
    let draft: String?
    let muteUntil: String?
    let codeUrl: String?
    let pinTime: String?
    let expireIn: Int64?
    let createdAt: String
    
    init(conversation: Conversation, to platform: DeviceTransferPlatform) {
        conversationId = conversation.conversationId
        ownerId = conversation.ownerId
        category = conversation.category
        name = conversation.name
        announcement = conversation.announcement
        lastMessageId = conversation.lastMessageId
        lastMessageCreatedAt = conversation.lastMessageCreatedAt
        lastReadMessageId = conversation.lastReadMessageId
        unseenMessageCount = conversation.unseenMessageCount
        if platform == .iOS {
            status = conversation.status
        } else {
            status = ConversationStatusConverter.toOtherPlatform(status: conversation.status).rawValue
        }
        draft = conversation.draft
        muteUntil = conversation.muteUntil
        codeUrl = conversation.codeUrl
        pinTime = conversation.pinTime
        expireIn = conversation.expireIn
        createdAt = conversation.createdAt.isEmpty ? "2017-10-25T00:00:00.000Z" : conversation.createdAt
    }
    
    func toConversation(from platform: DeviceTransferPlatform) -> Conversation {
        let conversationStatus: Int
        switch platform {
        case .iOS:
            conversationStatus = status
        case .other:
            conversationStatus = ConversationStatusConverter.toiOSPlatform(status: status).rawValue
        }
        return Conversation(conversationId: conversationId,
                            ownerId: ownerId,
                            category: category,
                            name: name,
                            iconUrl: nil,
                            announcement: announcement,
                            lastMessageId: lastMessageId,
                            lastMessageCreatedAt: lastMessageCreatedAt,
                            lastReadMessageId: lastReadMessageId,
                            unseenMessageCount: 0,
                            status: conversationStatus,
                            draft: draft,
                            muteUntil: muteUntil,
                            codeUrl: codeUrl,
                            pinTime: pinTime,
                            expireIn: expireIn,
                            createdAt: createdAt)
    }
    
    private enum ConversationStatusConverter {
        
        enum OtherPlatformConversationStatus: Int {
            case START = 0
            case FAILURE = 1
            case SUCCESS = 2
            case QUIT = 3
        }
        
        static func toiOSPlatform(status: Int) -> ConversationStatus {
            if let status = OtherPlatformConversationStatus(rawValue: status) {
                switch status {
                case .START, .FAILURE:
                    return ConversationStatus.START
                case .SUCCESS:
                    return ConversationStatus.SUCCESS
                case .QUIT:
                    return ConversationStatus.QUIT
                }
            } else {
                return ConversationStatus.START
            }
        }
        
        static func toOtherPlatform(status: Int) -> OtherPlatformConversationStatus {
            if let status = ConversationStatus(rawValue: status) {
                switch status {
                case .START:
                    return OtherPlatformConversationStatus.START
                case .SUCCESS:
                    return OtherPlatformConversationStatus.SUCCESS
                case .QUIT:
                    return OtherPlatformConversationStatus.QUIT
                }
            } else {
                return OtherPlatformConversationStatus.START
            }
        }
        
    }
    
}

extension DeviceTransferConversation: DeviceTransferRecord {
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case ownerId = "owner_id"
        case category
        case name
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
        case createdAt = "created_at"
    }
    
}
