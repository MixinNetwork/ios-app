import WCDBSwift

public final class MessageMentionDAO {
    
    public static let shared = MessageMentionDAO()
    
    private enum Sql {
        static let unreadMessageIds = """
        SELECT mm.message_id
        FROM \(MessageMention.tableName) mm
        LEFT JOIN \(Message.tableName) m ON m.id = mm.message_id
        WHERE mm.conversation_id = ? AND mm.has_read = 0
        ORDER BY m.created_at ASC
        """
    }
    
    public func unreadMessageIds(conversationId: String) -> [String] {
        MixinDatabase.shared.getStringValues(sql: Sql.unreadMessageIds, values: [conversationId])
    }
    
}
