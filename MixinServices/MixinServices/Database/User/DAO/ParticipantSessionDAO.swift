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
    
    public func getParticipantSessionKey(conversationId: String, userId: String) -> ParticipantSession.Key? {
        let sql = "SELECT * FROM participant_session WHERE conversation_id = ? AND user_id = ? LIMIT 1"
        return db.select(with: sql, arguments: [conversationId, userId])
    }
    
    public func getParticipantSessionKeyWithoutSelf(conversationId: String, userId: String) -> ParticipantSession.Key? {
        let sql = "SELECT * FROM participant_session WHERE conversation_id = ? AND user_id != ?"
        return db.select(with: sql, arguments: [conversationId, userId])
    }
    
    public func insertParticipantSessionSent(_ object: ParticipantSession.Sent) {
        db.save(object.participantSession)
    }
    
    public func updateParticipantSessionSent(_ objects: [ParticipantSession.Sent]) {
        db.write { (db) in
            for obj in objects {
                let condition: SQLSpecificExpressible = obj.conversationId == ParticipantSession.column(of: .conversationId)
                    && obj.userId == ParticipantSession.column(of: .userId)
                    && obj.sessionId == ParticipantSession.column(of: .sessionId)
                let assignments = [ParticipantSession.column(of: .sentToServer).set(to: obj.sentToServer)]
                try ParticipantSession.filter(condition).updateAll(db, assignments)
            }
        }
    }
    
    public func provisionSession(userId: String, sessionId: String, publicKey: String?) {
        let createdAt = Date().toUTCString()
        let sql = """
        INSERT OR REPLACE INTO participant_session(conversation_id, user_id, session_id, created_at, public_key)
        SELECT c.conversation_id, :user_id, :session_id, :created_at, :public_key FROM conversations c
        LEFT JOIN participants p on p.conversation_id = c.conversation_id
        WHERE p.user_id = :user_id
        """
        db.execute(sql: sql, arguments: [
            "user_id": userId,
            "session_id": sessionId,
            "created_at": createdAt,
            "public_key": publicKey
        ])
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
                                   createdAt: Date().toUTCString(),
                                   publicKey: $0.publicKey)
            }
            try sessionParticipants.save(db)
        }
    }
    
}
