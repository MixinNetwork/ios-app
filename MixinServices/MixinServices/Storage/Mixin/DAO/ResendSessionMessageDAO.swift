import GRDB

public final class ResendSessionMessageDAO: UserDatabaseDAO {
    
    public static let shared = ResendSessionMessageDAO()
    
    public func isExist(messageId: String, userId: String, sessionId: String) -> Bool {
        let condition: SQLSpecificExpressible = ResendSessionMessage.column(of: .messageId) == messageId
            && ResendSessionMessage.column(of: .userId) == userId
            && ResendSessionMessage.column(of: .sessionId) == sessionId
        return db.recordExists(in: ResendSessionMessage.self, where: condition)
    }
    
}
