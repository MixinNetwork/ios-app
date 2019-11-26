import WCDBSwift

final class ParticipantSessionDAO {

    private let sqlQueryParticipantUsers = """
    SELECT p.* FROM participant_session p
    LEFT JOIN users u ON p.user_id = u.user_id
    WHERE p.conversation_id = ? AND p.session_id != ? AND ifnull(u.app_id,'') == '' AND ifnull(p.sent_to_server,'') == ''
    """
    private let sqlInsertParticipantSession = """
    INSERT INTO participant_session(conversation_id, user_id, session_id, created_at)
    SELECT c.conversation_id, ?, ?, ? FROM conversations c
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

    static let shared = ParticipantSessionDAO()

    func getParticipantSessions(conversationId: String) -> [ParticipantSession] {
        return MixinDatabase.shared.getCodables(condition: ParticipantSession.Properties.conversationId == conversationId)
    }

    func getParticipantSession(conversationId: String, userId: String, sessionId: String) -> ParticipantSession? {
        return MixinDatabase.shared.getCodable(condition: ParticipantSession.Properties.conversationId == conversationId && ParticipantSession.Properties.userId == userId && ParticipantSession.Properties.sessionId == sessionId)
    }

    func getNotSendSessionParticipants(conversationId: String, sessionId: String) -> [ParticipantSession] {
        return MixinDatabase.shared.getCodables(on: ParticipantSession.Properties.all, sql: sqlQueryParticipantUsers, values: [conversationId, sessionId])
    }

    func updateStatusByUserId(userId: String) {
        MixinDatabase.shared.update(maps: [(ParticipantSession.Properties.sentToServer, nil)], tableName: ParticipantSession.tableName, condition: ParticipantSession.Properties.userId == userId)
    }

    func provisionSession(userId: String, sessionId: String) {
        MixinDatabase.shared.execute(sql: sqlInsertParticipantSession, values: [userId, sessionId, Date().toUTCString(), userId])
//        let participantSessions = conversationIds.map { ParticipantSession(conversationId: $0, userId: userId, sessionId: sessionId, sentToServer: nil, createdAt: Date().toUTCString()) }
//        MixinDatabase.shared.insertOrReplace(objects: participantSessions)
    }

    func destorySession(userId: String, sessionId: String) {
        MixinDatabase.shared.execute(sql: sqlDeleteParticipantSession, values: [userId, sessionId, userId])
//        MixinDatabase.shared.delete(table: ParticipantSession.tableName, condition: ParticipantSession.Properties.conversationId.in(conversationIds)
//            && ParticipantSession.Properties.userId == userId
//            && ParticipantSession.Properties.sessionId == sessionId)
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

