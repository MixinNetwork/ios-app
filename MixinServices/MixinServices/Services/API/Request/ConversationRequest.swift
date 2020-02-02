import Foundation

public struct ConversationRequest: Encodable {
    
    public let conversationId: String
    public let name: String?
    public let category: String?
    public let participants: [ParticipantRequest]?
    public let duration: Int64?
    public let announcement: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case name
        case category
        case participants
        case duration
        case announcement
    }
    
    public init(conversationId: String, name: String?, category: String?, participants: [ParticipantRequest]?, duration: Int64?, announcement: String?) {
        self.conversationId = conversationId
        self.name = name
        self.category = category
        self.participants = participants
        self.duration = duration
        self.announcement = announcement
    }
    
}
