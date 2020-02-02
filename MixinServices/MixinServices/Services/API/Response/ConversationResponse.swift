import Foundation

public struct ConversationResponse: Codable {
    
    public let conversationId: String
    public let name: String
    public let category: String
    public let iconUrl: String
    public let announcement: String
    public let createdAt: String
    public let participants: [ParticipantResponse]
    public let participantSessions: [UserSession]?
    public let codeUrl: String
    public let creatorId: String
    public let muteUntil: String
    
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
    
    public init(conversationId: String, name: String, category: String, iconUrl: String, announcement: String, createdAt: String, participants: [ParticipantResponse], participantSessions: [UserSession]?, codeUrl: String, creatorId: String, muteUntil: String) {
        self.conversationId = conversationId
        self.name = name
        self.category = category
        self.iconUrl = iconUrl
        self.announcement = announcement
        self.createdAt = createdAt
        self.participants = participants
        self.participantSessions = participantSessions
        self.codeUrl = codeUrl
        self.creatorId = creatorId
        self.muteUntil = muteUntil
    }
    
}

public struct ParticipantResponse: Codable {
    
    public let userId: String
    public let role: String
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case createdAt = "created_at"
    }
    
    public init(userId: String, role: String, createdAt: String) {
        self.userId = userId
        self.role = role
        self.createdAt = createdAt
    }
    
}
