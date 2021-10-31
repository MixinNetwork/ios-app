import GRDB

public final class MessageHistoryDAO: UserDatabaseDAO {
    
    public static let shared = MessageHistoryDAO()
    
    public func isExist(messageId: String) -> Bool {
        db.recordExists(in: MessageHistory.self,
                        where: MessageHistory.column(of: .messageId) == messageId)
    }
    
    public func getExistMessageIds(messageIds: [String]) -> [String] {
        guard messageIds.count > 0 else {
            return []
        }
        return db.select(column: MessageHistory.column(of: .messageId),
                  from: MessageHistory.self,
                  where: messageIds.contains(MessageHistory.column(of: .messageId)))
    }
    
    public func replaceMessageHistory(messageId: String) {
        let history = MessageHistory(messageId: messageId)
        db.save(history)
    }
    
}
