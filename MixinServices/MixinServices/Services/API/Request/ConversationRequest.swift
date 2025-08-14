import Foundation

public struct ConversationRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case name
        case category
        case participants
        case duration
        case announcement
        case randomID = "random_id"
    }
    
    public let conversationId: String
    public let name: String?
    public let category: String?
    public let participants: [ParticipantRequest]?
    public let duration: Int64?
    public let announcement: String?
    public let randomID: String?
    
    public init(conversationId: String, name: String?, category: String?, participants: [ParticipantRequest]?, duration: Int64?, announcement: String?, randomID: String?) {
        self.conversationId = conversationId
        self.name = name
        self.category = category
        self.participants = participants
        self.duration = duration
        self.announcement = announcement
        self.randomID = randomID
    }
    
}
