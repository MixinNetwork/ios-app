import WCDBSwift

public final class ParticipantSessionDAO {
    
    private let sqlQueryParticipantUsers = """
    SELECT p.* FROM participant_session p
    LEFT JOIN users u ON p.user_id = u.user_id
    WHERE p.conversation_id = ? AND p.session_id != ? AND ifnull(u.app_id,'') == '' AND ifnull(p.sent_to_server,'') == ''
    """
    private let sqlInsertParticipantSession = """
    INSERT OR REPLACE INTO participant_session(conversation_id, user_id, session_id, created_at)
    SELECT c.conversation_id, '%@', '%@', '%@' FROM conversations c
    INNER JOIN users u ON c.owner_id = u.user_id
    LEFT JOIN participants p on p.conversation_id = c.conversation_id
    WHERE p.user_id = ? AND ifnull(u.app_id, '') = ''
    """
    private let sqlDeleteParticipantSession = """
    DELETE FROM participant_session WHERE user_id = ? AND session_id = ?
    AND conversation_id in (
        SELECT c.conversation_id FROM conversations c
        INNER JOIN users u ON c.owner_id = u.user_id
        LEFT JOIN participants p on p.conversation_id = c.conversation_id
        WHERE p.user_id = ? AND ifnull(u.app_id, '') = ''
    )
    """
    
    public static let shared = ParticipantSessionDAO()
    
    public func getParticipantSessions(conversationId: String) -> [ParticipantSession] {
        return MixinDatabase.shared.getCodables(condition: ParticipantSession.Properties.conversationId == conversationId)
    }
    
    public func getParticipantSession(conversationId: String, userId: String, sessionId: String) -> ParticipantSession? {
        return MixinDatabase.shared.getCodable(condition: ParticipantSession.Properties.conversationId == conversationId && ParticipantSession.Properties.userId == userId && ParticipantSession.Properties.sessionId == sessionId)
    }
    
    public func getNotSendSessionParticipants(conversationId: String, sessionId: String) -> [ParticipantSession] {
        return MixinDatabase.shared.getCodables(on: ParticipantSession.Properties.all, sql: sqlQueryParticipantUsers, values: [conversationId, sessionId])
    }
    
    public func updateStatusByUserId(userId: String) {
        MixinDatabase.shared.update(maps: [(ParticipantSession.Properties.sentToServer, nil)], tableName: ParticipantSession.tableName, condition: ParticipantSession.Properties.userId == userId)
    }
    
    public func provisionSession(userId: String, sessionId: String) {
        MixinDatabase.shared.execute(sql: String(format: sqlInsertParticipantSession, userId, sessionId, Date().toUTCString()), values: [userId])
    }
    
    public func destorySession(userId: String, sessionId: String) {
        MixinDatabase.shared.execute(sql: sqlDeleteParticipantSession, values: [userId, sessionId, userId])
    }
    
    public func syncConversationParticipantSession(conversation: ConversationResponse) {
        let conversationId = conversation.conversationId
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: Participant.tableName, where: Participant.Properties.conversationId == conversationId)
            let participants = conversation.participants.map { Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.START.rawValue, createdAt: $0.createdAt) }
            try db.insertOrReplace(objects: participants, intoTable: Participant.tableName)
            try ParticipantSessionDAO.shared.syncConversationParticipantSession(conversation: conversation, db: db)
        }
    }
    
    public func syncConversationParticipantSession(conversation: ConversationResponse, db: Database) throws {
        let conversationId = conversation.conversationId
        var sentToServerMap = [String: Int?]()
        
        let oldParticipantSessions: [ParticipantSession] = try db.getObjects(on: ParticipantSession.Properties.all, fromTable: ParticipantSession.tableName, where: ParticipantSession.Properties.conversationId == conversationId)
        oldParticipantSessions.forEach({ (participantSession) in
            sentToServerMap[participantSession.uniqueIdentifier] = participantSession.sentToServer
        })
        try db.delete(fromTable: ParticipantSession.tableName, where: ParticipantSession.Properties.conversationId == conversationId)
        
        if let participantSessions = conversation.participantSessions {
            let sessionParticipants = participantSessions.map {
                ParticipantSession(conversationId: conversationId, userId: $0.userId, sessionId: $0.sessionId, sentToServer: sentToServerMap[$0.uniqueIdentifier] ?? nil, createdAt: Date().toUTCString())
            }
            try db.insert(objects: sessionParticipants, intoTable: ParticipantSession.tableName)
        }
    }
    
}
