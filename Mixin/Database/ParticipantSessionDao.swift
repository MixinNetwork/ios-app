import WCDBSwift

final class ParticipantSessionDao {

    private static let sqlQueryParticipantUsers = """
    SELECT p.* FROM participant_session p WHERE p.conversation_id = :conversationId AND p.session_id != :sessionId AND ifnull(p.sent_to_server,'') == ''
    """

    static let shared = MessageHistoryDAO()

    func getParticipantSessions(conversationId: String) -> [ParticipantSession] {
        return MixinDatabase.shared.getCodables(condition: ParticipantSession.Properties.conversationId == conversationId)
    }

    func delete(conversationId: String) {
        MixinDatabase.shared.delete(table: ParticipantSession.tableName, condition: ParticipantSession.Properties.conversationId == conversationId)
    }

    func getNotSendSessionParticipants(conversationId: String, sessionId: String) -> [ParticipantSession] {
        return MixinDatabase.shared.getCodables(on: ParticipantSession.Properties.all, sql: ParticipantSessionDao.sqlQueryParticipantUsers, values: [conversationId, sessionId])
    }
}

