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
    
    public func messageMentions(
        limit: Int,
        after messageId: String?,
        matching conversationIDs: Set<String>?
    ) -> [MessageMention] {
        var sql = "SELECT * FROM message_mentions"
       
        var conditions: [String] = []
        if let messageId {
            conditions.append("rowid > IFNULL((SELECT rowid FROM message_mentions WHERE message_id = '\(messageId)'), 0)")
        }
        if let conversationIDs {
            let ids = conversationIDs.joined(separator: "', '")
            conditions.append("conversation_id IN ('\(ids)')")
        }
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        
        sql += " ORDER BY rowid ASC LIMIT ?"
        return db.select(with: sql, arguments: [limit])
    }
    
    public func messageMentionsCount(matching conversationIDs: [String]?) -> Int {
        if let conversationIDs {
            var totalCount = 0
            for i in stride(from: 0, to: conversationIDs.count, by: Self.deviceTransferStride) {
                let endIndex = min(i + Self.deviceTransferStride, conversationIDs.count)
                let ids = Array(conversationIDs[i..<endIndex]).joined(separator: "', '")
                let sql = "SELECT COUNT(*) FROM message_mentions WHERE conversation_id IN ('\(ids)')"
                let count: Int? = db.select(with: sql)
                totalCount += (count ?? 0)
            }
            return totalCount
        } else {
            let count: Int? = db.select(with: "SELECT COUNT(*) FROM message_mentions")
            return count ?? 0
        }
    }
    
    public func save(messageMention: MessageMention) {
        db.save(messageMention)
    }
    
}
