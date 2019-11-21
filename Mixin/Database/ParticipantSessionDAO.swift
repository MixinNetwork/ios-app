import WCDBSwift

final class ParticipantSessionDAO {

    private static let sqlQueryParticipantUsers = """
    SELECT p.* FROM participant_session p WHERE p.conversation_id = :conversationId AND p.session_id != :sessionId AND ifnull(p.sent_to_server,'') == ''
    """

    static let shared = ParticipantSessionDAO()

    func getParticipantSessions(conversationId: String) -> [ParticipantSession] {
        return MixinDatabase.shared.getCodables(condition: ParticipantSession.Properties.conversationId == conversationId)
    }

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
    
}

