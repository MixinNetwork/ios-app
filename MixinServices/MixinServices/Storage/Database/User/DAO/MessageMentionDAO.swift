import GRDB

public final class MessageMentionDAO: UserDatabaseDAO {
    
    public static let shared = MessageMentionDAO()
    
    public func unreadMessageIds(conversationId: String) -> [String] {
        let sql = """
        SELECT mm.message_id
        FROM \(MessageMention.databaseTableName) mm
        LEFT JOIN \(Message.databaseTableName) m ON m.id = mm.message_id
        WHERE mm.conversation_id = ? AND mm.has_read = 0
        ORDER BY m.created_at ASC
        """
        return db.select(with: sql, arguments: [conversationId])
    }
    
}
