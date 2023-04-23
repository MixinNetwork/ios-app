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
    
    public func messageMentions(limit: Int, offset: Int) -> [MessageMention] {
        let sql = "SELECT * FROM message_mentions ORDER BY rowid LIMIT ? OFFSET ?"
        return db.select(with: sql, arguments: [limit, offset])
    }
    
    public func messageMentionsCount() -> Int {
        let count: Int? = db.select(with: "SELECT COUNT(*) FROM message_mentions")
        return count ?? 0
    }
    
    public func insert(messageMention: MessageMention) {
        db.save(messageMention)
    }
    
}
