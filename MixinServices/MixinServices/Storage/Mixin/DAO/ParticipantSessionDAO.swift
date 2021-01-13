import GRDB

public final class ParticipantSessionDAO: UserDatabaseDAO {
    
    public static let shared = ParticipantSessionDAO()
    
    public func getParticipantSessions(conversationId: String) -> [ParticipantSession] {
        db.select(where: ParticipantSession.column(of: .conversationId) == conversationId)
    }
    
    public func getParticipantSession(conversationId: String, userId: String, sessionId: String) -> ParticipantSession? {
        let condition: SQLSpecificExpressible = ParticipantSession.column(of: .conversationId) == conversationId
            && ParticipantSession.column(of: .userId) == userId
            && ParticipantSession.column(of: .sessionId) == sessionId
        return db.select(where: condition)
    }
    
    public func getNotSendSessionParticipants(conversationId: String, sessionId: String) -> [ParticipantSession] {
        let sql = """
        SELECT p.* FROM participant_session p
        LEFT JOIN users u ON p.user_id = u.user_id
        WHERE p.conversation_id = ? AND p.session_id != ? AND ifnull(u.app_id,'') == '' AND ifnull(p.sent_to_server,'') == ''
        """
        return db.select(with: sql, arguments: [conversationId, sessionId])
    }

    public func provisionSession(userId: String, sessionId: String) {
        let sql = """
        INSERT OR REPLACE INTO participant_session(conversation_id, user_id, session_id, created_at)
        SELECT c.conversation_id, '%@', '%@', '%@' FROM conversations c
        INNER JOIN users u ON c.owner_id = u.user_id
        LEFT JOIN participants p on p.conversation_id = c.conversation_id
        WHERE p.user_id = ? AND ifnull(u.app_id, '') = ''
        """
        let formatted = String(format: sql, userId, sessionId, Date().toUTCString())
        db.execute(sql: sql, arguments: [userId])
    }

    public func destorySession(userId: String, sessionId: String) {
        let sql = """
        DELETE FROM participant_session WHERE user_id = ? AND session_id = ?
        """
        db.execute(sql: sql, arguments: [userId, sessionId])
    }

    public func syncConversationParticipantSession(conversation: ConversationResponse) {
        let conversationId = conversation.conversationId
        db.write { (db) in
            try Participant
                .filter(Participant.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            
            let participants = conversation.participants.map {
                Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.START.rawValue, createdAt: $0.createdAt)
            }
            try participants.save(db)
            
            try db.execute(sql: ParticipantDAO.sqlUpdateStatus, arguments: [conversationId])
            try ParticipantSessionDAO.shared.syncConversationParticipantSession(conversation: conversation, db: db)
        }
    }

    public func syncConversationParticipantSession(conversation: ConversationResponse, db: GRDB.Database) throws {
        let conversationId = conversation.conversationId
        var sentToServerMap = [String: Int?]()
        
        let oldParticipantSessions = try ParticipantSession
            .filter(ParticipantSession.column(of: .conversationId) == conversationId)
            .fetchAll(db)
        for session in oldParticipantSessions {
            sentToServerMap[session.uniqueIdentifier] = session.sentToServer
        }
        
        try ParticipantSession
            .filter(ParticipantSession.column(of: .conversationId) == conversationId)
            .deleteAll(db)
        
        if let participantSessions = conversation.participantSessions {
            let sessionParticipants = participantSessions.map {
                ParticipantSession(conversationId: conversationId,
                                   userId: $0.userId,
                                   sessionId: $0.sessionId,
                                   sentToServer: sentToServerMap[$0.uniqueIdentifier] ?? nil,
                                   createdAt: Date().toUTCString())
            }
            try sessionParticipants.save(db)
        }
    }
    
}
