import WCDBSwift

final class SessionSyncDAO {

    static let shared = SessionSyncDAO()

    func getSyncSessions(conversationId: String) -> [SessionSync] {
        return MixinDatabase.shared.getCodables(condition: SessionSync.Properties.conversationId == conversationId)
    }

    func getSyncSessions() -> [SessionSync] {
        return MixinDatabase.shared.getCodables(orderBy: [SessionSync.Properties.createdAt.asOrder(by: .descending)], limit: 50)
    }

    func removeSyncSessions(conversationIds: [String]) {
        MixinDatabase.shared.delete(table: SessionSync.tableName, condition: SessionSync.Properties.conversationId.in(conversationIds))
    }

    func saveSyncSessions(userId: String, sessionId: String, syncSessions: [SessionSync]) {
        guard syncSessions.count > 0 else {
            return
        }
        let participentSessions = syncSessions.compactMap {
            ParticipantSession(conversationId: $0.conversationId, userId: userId, sessionId: sessionId, sentToServer: nil, createdAt: Date().toUTCString())
        }
        MixinDatabase.shared.transaction { (db) in
            try db.insertOrReplace(objects: syncSessions, intoTable: SessionSync.tableName)
            try db.insertOrReplace(objects: participentSessions, intoTable: ParticipantSession.tableName)
        }
    }
}

