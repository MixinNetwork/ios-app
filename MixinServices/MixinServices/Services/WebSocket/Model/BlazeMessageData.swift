import Foundation

public struct BlazeMessageData: Codable {
    
    public let conversationId: String
    public var userId: String
    public var messageId: String
    public let category: String
    public let data: String
    public let status: String
    public let createdAt: String
    public let updatedAt: String
    public let source: String
    public let quoteMessageId: String
    public let representativeId: String
    public let sessionId: String
    
    public let silentNotification: Bool
    public let expireIn: Int64
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        conversationId = try container.decode(String.self, forKey: .conversationId)
        userId = try container.decode(String.self, forKey: .userId)
        messageId = try container.decode(String.self, forKey: .messageId)
        category = try container.decode(String.self, forKey: .category)
        data = try container.decode(String.self, forKey: .data)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        source = try container.decode(String.self, forKey: .source)
        quoteMessageId = try container.decode(String.self, forKey: .quoteMessageId)
        representativeId = try container.decode(String.self, forKey: .representativeId)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        
        // When adding new properties, use `decodeIfPresent` to prevent `DecodingError.keyNotFound` when decoding jobs saved by elder version
        silentNotification = try container.decodeIfPresent(Bool.self, forKey: .silentNotification) ?? false
        expireIn = try container.decodeIfPresent(Int64.self, forKey: .expireIn) ?? 0
    }
    
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
        case silentNotification = "silent"
        case expireIn = "expire_in"
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
