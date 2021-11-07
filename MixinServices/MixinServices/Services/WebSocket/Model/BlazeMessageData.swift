import Foundation

public struct BlazeMessageData: Codable {
    
    public var conversationId: String
    public var userId: String
    public var messageId: String
    public var category: String
    public var data: String
    public var status: String
    public var createdAt: String
    public var updatedAt: String
    public var source: String
    public var quoteMessageId: String
    public var representativeId: String
    public var sessionId: String
    
    public var silentNotification: Bool {
        isSilent ?? false
    }
    
    private var isSilent: Bool?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case messageId = "message_id"
        case category
        case data
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case source
        case quoteMessageId = "quote_message_id"
        case representativeId = "representative_id"
        case sessionId = "session_id"
        case isSilent = "silent"
    }
    
    public init(conversationId: String, userId: String, messageId: String, category: String, data: String, status: String, createdAt: String,updatedAt: String, source: String, quoteMessageId: String, representativeId: String, sessionId: String, isSilent: Bool?) {
        self.conversationId = conversationId
        self.userId = userId
        self.messageId = messageId
        self.category = category
        self.data = data
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.quoteMessageId = quoteMessageId
        self.representativeId = representativeId
        self.sessionId = sessionId
        self.isSilent = isSilent
    }
}

public extension BlazeMessageData {
    
    func getSenderId() -> String {
        guard !representativeId.isEmpty else {
            return userId
        }
        return representativeId
    }
    
    func getDataUserId() -> String? {
        return representativeId.isEmpty ? nil : userId
    }
    
}
