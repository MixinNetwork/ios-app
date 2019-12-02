import Foundation

struct ConversationResponse: Codable {

    let conversationId: String
    let name: String
    let category: String
    let iconUrl: String
    let announcement: String
    let createdAt: String
    let participants: [ParticipantResponse]
    let participantSessions: [UserSession]?
    let codeUrl: String
    let creatorId: String
    let muteUntil: String

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case name
        case category
        case iconUrl = "icon_url"
        case announcement
        case createdAt = "created_at"
        case participants
        case codeUrl = "code_url"
        case creatorId = "creator_id"
        case muteUntil = "mute_until"
        case participantSessions = "participant_sessions"
    }
}

struct ParticipantResponse: Codable {

    let userId: String
    let role: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case createdAt = "created_at"
    }
}
