import WCDBSwift

final class SessionSyncDAO {

    static let shared = SessionSyncDAO()

    func getSyncSessions(conversationId: String) -> [SessionSync] {
        return MixinDatabase.shared.getCodables(condition: SessionSync.Properties.conversationId == conversationId)
    }

    func getSyncSessions() -> [SessionSync] {
        return MixinDatabase.shared.getCodables(orderBy: [SessionSync.Properties.createdAt.asOrder(by: .descending)], limit: 50)
    }
    
}

