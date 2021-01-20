import GRDB

public final class MessageHistoryDAO: UserDatabaseDAO {
    
    public static let shared = MessageHistoryDAO()
    
    public func isExist(messageId: String) -> Bool {
        db.recordExists(in: MessageHistory.self,
                        where: MessageHistory.column(of: .messageId) == messageId)
    }
    
    public func replaceMessageHistory(messageId: String) {
        let history = MessageHistory(messageId: messageId)
        db.save(history)
    }
    
}
