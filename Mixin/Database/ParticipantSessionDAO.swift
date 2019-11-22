import WCDBSwift

final class ParticipantSessionDAO {

    private static let sqlQueryParticipantUsers = """
    SELECT p.* FROM participant_session p
    LEFT JOIN users u ON p.user_id = u.user_id
    WHERE p.conversation_id = ? AND p.session_id != ? AND ifnull(u.app_id,'') == '' AND ifnull(p.sent_to_server,'') == ''
    """

    static let shared = ParticipantSessionDAO()

    func delete(conversationId: String) {
        MixinDatabase.shared.delete(table: ParticipantSession.tableName, condition: ParticipantSession.Properties.conversationId == conversationId)
    }

    func getNotSendSessionParticipants(conversationId: String, sessionId: String) -> [ParticipantSession] {
        return MixinDatabase.shared.getCodables(on: ParticipantSession.Properties.all, sql: ParticipantSessionDAO.sqlQueryParticipantUsers, values: [conversationId, sessionId])
    }

    func insertParticipentSession(participantSession: ParticipantSession) {
        MixinDatabase.shared.insertOrReplace(objects: [participantSession])
    }

    func updateStatusByUserId(userId: String) {
        MixinDatabase.shared.update(maps: [(ParticipantSession.Properties.sentToServer, nil)], tableName: ParticipantSession.tableName, condition: ParticipantSession.Properties.userId == userId)
    }

    func delete(userId: String, sessionId: String, syncSessions: [SessionSync]) {
        let conversationIds = syncSessions.map { $0.conversationId }
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: ParticipantSession.tableName, where:       ParticipantSession.Properties.conversationId.in(conversationIds)
                && ParticipantSession.Properties.userId == userId
                && ParticipantSession.Properties.sessionId == sessionId)
            try db.insertOrReplace(objects: syncSessions, intoTable: SessionSync.tableName)
        }
    }

    func syncConversationParticipantSession(conversation: ConversationResponse) {
        MixinDatabase.shared.transaction { (db) in
            try ParticipantSessionDAO.shared.syncConversationParticipantSession(conversation: conversation, db: db)
        }
    }

    func syncConversationParticipantSession(conversation: ConversationResponse, db: Database) throws {
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

