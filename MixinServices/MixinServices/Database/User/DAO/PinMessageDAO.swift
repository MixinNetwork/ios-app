import GRDB

public final class PinMessageDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let conversationId = "cid"
        public static let referencedMessageId = "rmid"
        public static let referencedMessageIds = "rmids"
        public static let messageId = "mid"
    }
    
    public static let shared = PinMessageDAO()
    
    public static let didSaveNotification = Notification.Name("one.mixin.services.PinMessageDAO.DidSave")
    
    // When this notification is posted with no referencedMessageIds in userinfo, it means that all pin messages
    // in this conversation are deleted
    public static let didDeleteNotification = Notification.Name("one.mixin.services.PinMessageDAO.DidDelete")
    
    public func messageItems(conversationId: String) -> [MessageItem] {
        let sql = """
        \(MessageDAO.sqlQueryFullMessage)
        INNER JOIN pin_messages p ON m.id = p.message_id
        WHERE m.conversation_id = ?
        ORDER BY m.created_at ASC
        """
        return db.select(with: sql, arguments: [conversationId])
    }
    
    public func delete(messageIds: [String], conversationId: String, from database: GRDB.Database) throws {
        let deletedCount = try PinMessage
            .filter(messageIds.contains(PinMessage.column(of: .messageId)))
            .deleteAll(database)
        database.afterNextTransactionCommit { db in
            if deletedCount > 0 {
                if let id = AppGroupUserDefaults.User.pinMessageBanners[conversationId], let quoteMessageId = MessageDAO.shared.quoteMessageId(messageId: id), messageIds.contains(quoteMessageId) {
                    AppGroupUserDefaults.User.pinMessageBanners[conversationId] = nil
                }
                let userInfo: [String: Any] = [
                    PinMessageDAO.UserInfoKey.conversationId: conversationId,
                    PinMessageDAO.UserInfoKey.referencedMessageIds: messageIds,
                ]
                NotificationCenter.default.post(onMainThread: PinMessageDAO.didDeleteNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
    }
    
    public func delete(messageIds: [String], conversationId: String) {
        db.write { (db) in
            try delete(messageIds: messageIds, conversationId: conversationId, from: db)
        }
    }
    
    public func save(
        referencedItem: MessageItem,
        source: String,
        silentNotification: Bool,
        pinMessage message: Message,
        mention: MessageMention? = nil
    ) {
        let pinMessage = PinMessage(messageId: referencedItem.messageId, conversationId: referencedItem.conversationId, createdAt: message.createdAt)
        db.write { db in
            try pinMessage.save(db)
            try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: source, silentNotification: silentNotification)
            try mention?.save(db)
            db.afterNextTransactionCommit { db in
                AppGroupUserDefaults.User.pinMessageBanners[referencedItem.conversationId] = message.messageId
                let userInfo: [String: Any] = [
                    PinMessageDAO.UserInfoKey.conversationId: referencedItem.conversationId,
                    PinMessageDAO.UserInfoKey.referencedMessageId: referencedItem.messageId,
                    PinMessageDAO.UserInfoKey.messageId: message.messageId
                ]
                NotificationCenter.default.post(onMainThread: PinMessageDAO.didSaveNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
    }
    
    public func deleteAll(conversationId: String, from database: GRDB.Database) throws {
        try PinMessage
            .filter(PinMessage.column(of: .conversationId) == conversationId)
            .deleteAll(database)
        database.afterNextTransactionCommit { db in
            AppGroupUserDefaults.User.pinMessageBanners[conversationId] = nil
            NotificationCenter.default.post(onMainThread: PinMessageDAO.didDeleteNotification,
                                            object: self,
                                            userInfo: [PinMessageDAO.UserInfoKey.conversationId: conversationId])
        }
    }
    
    public func hasMessage(conversationId: String) -> Bool {
        db.recordExists(in: PinMessage.self,
                        where: PinMessage.column(of: .conversationId) == conversationId)
    }
    
}
