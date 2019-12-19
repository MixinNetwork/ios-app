import Foundation

public struct ConversationRequest: Encodable {
    
    let conversationId: String
    let name: String?
    let category: String?
    let participants: [ParticipantRequest]?
    let duration: Int64?
    let announcement: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case name
        case category
        case participants
        case duration
        case announcement
    }
    
}
