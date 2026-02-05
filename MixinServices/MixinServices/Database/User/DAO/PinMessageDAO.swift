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
            SELECT m.id, m.conversation_id, m.user_id, m.category, m.content, m.media_url, m.media_mime_type,
                m.media_size, m.media_duration, m.media_width, m.media_height, m.media_hash, m.media_key,
                m.media_digest, m.media_status, m.media_waveform, m.thumb_image, m.thumb_url, 
                m.status, m.participant_id, m.snapshot_id, m.name, m.sticker_id, m.created_at,
                u.full_name as userFullName, u.identity_number as userIdentityNumber, u.avatar_url as userAvatarUrl, 
                u.app_id as appId, u.membership as userMembership,
                u1.full_name as participantFullName, u1.user_id as participantUserId,
                NULL, NULL, NULL, NULL, NULL,
                st.asset_width as assetWidth, st.asset_height as assetHeight, st.asset_url as assetUrl, 
                st.asset_type as assetType, alb.category as assetCategory,
                m.action as actionName, m.shared_user_id as sharedUserId,
                su.full_name as sharedUserFullName, su.identity_number as sharedUserIdentityNumber, 
                su.avatar_url as sharedUserAvatarUrl, su.app_id as sharedUserAppId,
                su.is_verified as sharedUserIsVerified, su.membership as sharedUserMembership,
                m.quote_message_id, m.quote_content,
                mm.mentions, mm.has_read as hasMentionRead, 0 AS pinned
            FROM pin_messages p
            INNER JOIN messages m ON p.message_id = m.id
            LEFT JOIN users u ON m.user_id = u.user_id
            LEFT JOIN users u1 ON m.participant_id = u1.user_id
            LEFT JOIN stickers st ON m.sticker_id = st.sticker_id
            LEFT JOIN albums alb ON alb.album_id = (
                SELECT album_id FROM sticker_relationships sr WHERE sr.sticker_id = m.sticker_id LIMIT 1
            )
            LEFT JOIN users su ON m.shared_user_id = su.user_id
            LEFT JOIN message_mentions mm ON m.id = mm.message_id
            WHERE p.conversation_id = ?
            ORDER BY m.created_at ASC
        """
        return db.select(with: sql, arguments: [conversationId])
    }
    
    public func delete(messageIds: [String], conversationId: String, from database: GRDB.Database) throws {
        let deletedCount = try PinMessage
            .filter(messageIds.contains(PinMessage.column(of: .messageId)))
            .deleteAll(database)
        database.afterNextTransaction { db in
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
            db.afterNextTransaction { db in
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
        database.afterNextTransaction { db in
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
    
    public func pinMessages(limit: Int, after messageId: String?) -> [PinMessage] {
        var sql = "SELECT * FROM pin_messages"
        if let messageId {
            sql += " WHERE ROWID > IFNULL((SELECT ROWID FROM pin_messages WHERE message_id = '\(messageId)'), 0)"
        }
        sql += " ORDER BY ROWID LIMIT ?"
        return db.select(with: sql, arguments: [limit])
    }
    
    public func pinMessagesCount() -> Int {
        let count: Int? = db.select(with: "SELECT COUNT(*) FROM pin_messages")
        return count ?? 0
    }
    
    public func save(pinMessage: PinMessage) {
        db.save(pinMessage)
    }
    
}
