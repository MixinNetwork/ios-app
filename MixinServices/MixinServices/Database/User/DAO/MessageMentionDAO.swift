import GRDB

public final class MessageMentionDAO: UserDatabaseDAO {
    
    public static let shared = MessageMentionDAO()
    
    public static let didUpdateHasReadNotification = Notification.Name("one.mixin.messenger.MessageMentionDAO.didUpdateHasRead")
    public static let messageIdUserInfoKey = "mid"
    
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
    
    public func setMessageMentionHasRead(with messageId: String, onChange: @escaping () -> Void) {
        db.write { (db) in
            let changes = try MessageMention
                .filter(MessageMention.column(of: .messageId) == messageId && !MessageMention.column(of: .hasRead))
                .updateAll(db, [MessageMention.column(of: .hasRead).set(to: true)])
            if changes > 0 {
                db.afterNextTransactionCommit { (_) in
                    DispatchQueue.global().async {
                        NotificationCenter.default.post(onMainThread: Self.didUpdateHasReadNotification,
                                                        object: self,
                                                        userInfo: [Self.messageIdUserInfoKey: messageId])
                        onChange()
                    }
                }
            }
        }
    }
    
}
