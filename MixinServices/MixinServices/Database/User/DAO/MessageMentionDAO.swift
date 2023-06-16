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
    
    public func messageMentions(limit: Int, after messageId: String?) -> [MessageMention] {
        var sql = "SELECT * FROM message_mentions"
        if let messageId {
            sql += " WHERE ROWID > IFNULL((SELECT ROWID FROM message_mentions WHERE message_id = '\(messageId)'), 0)"
        }
        sql += " ORDER BY ROWID LIMIT ?"
        return db.select(with: sql, arguments: [limit])
    }
    
    public func messageMentionsCount() -> Int64 {
        let count: Int64? = db.select(with: "SELECT COUNT(*) FROM message_mentions")
        return count ?? 0
    }
    
    public func save(messageMention: MessageMention) {
        db.save(messageMention)
    }
    
}
