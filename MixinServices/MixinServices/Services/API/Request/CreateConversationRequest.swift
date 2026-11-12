import Foundation

public struct CreateConversationRequest: Encodable {
    
    public let conversationID: String
    public let name: String?
    public let category: String?
    public let participants: [ParticipantRequest]
    public let randomID: String?
    
    private enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case name
        case category
        case participants
        case randomID = "random_id"
    }
    
    public init(
        conversationID: String,
        name: String?,
        category: String?,
        participants: [ParticipantRequest],
        randomID: String?,
    ) {
        self.conversationID = conversationID
        self.name = name
        self.category = category
        self.participants = participants
        self.randomID = randomID
    }
    
}
