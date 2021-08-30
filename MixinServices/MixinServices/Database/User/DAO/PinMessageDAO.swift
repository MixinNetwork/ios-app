import GRDB

public final class PinMessageDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let conversationId = "conv_id"
        public static let messageId = "mid"
        public static let isPinned = "is_p"
        public static let message = "msg"
    }
    
    public static let shared = PinMessageDAO()
    
    public static let pinMessageDidChangeNotification = NSNotification.Name("one.mixin.services.PinMessageDAO.pinMessageDidChange")
    
    static let messageItemQuery = """
    SELECT m.id, m.conversation_id, m.user_id, m.category, m.content, m.media_url, m.media_mime_type,
        m.media_size, m.media_duration, m.media_width, m.media_height, m.media_hash, m.media_key,
        m.media_digest, m.media_status, m.media_waveform, m.media_local_id, m.thumb_image, m.thumb_url, m.status, m.participant_id, m.snapshot_id, m.name,
        m.sticker_id, m.created_at, u.full_name as userFullName, u.identity_number as userIdentityNumber, u.avatar_url as userAvatarUrl, u.app_id as appId,
        u1.full_name as participantFullName, u1.user_id as participantUserId,
               s.amount as snapshotAmount, s.asset_id as snapshotAssetId, s.type as snapshotType, a.symbol as assetSymbol, a.icon_url as assetIcon,
               st.asset_width as assetWidth, st.asset_height as assetHeight, st.asset_url as assetUrl, st.asset_type as assetType, alb.category as assetCategory,
               m.action as actionName, m.shared_user_id as sharedUserId, su.full_name as sharedUserFullName, su.identity_number as sharedUserIdentityNumber, su.avatar_url as sharedUserAvatarUrl, su.app_id as sharedUserAppId, su.is_verified as sharedUserIsVerified, m.quote_message_id, m.quote_content,
        mm.mentions, mm.has_read as hasMentionRead
    FROM messages m
    LEFT JOIN users u ON m.user_id = u.user_id
    LEFT JOIN users u1 ON m.participant_id = u1.user_id
    LEFT JOIN snapshots s ON m.snapshot_id = s.snapshot_id
    LEFT JOIN assets a ON s.asset_id = a.asset_id
    LEFT JOIN stickers st ON m.sticker_id = st.sticker_id
    LEFT JOIN albums alb ON alb.album_id = (
        SELECT album_id FROM sticker_relationships sr WHERE sr.sticker_id = m.sticker_id LIMIT 1
    )
    LEFT JOIN users su ON m.shared_user_id = su.user_id
    LEFT JOIN message_mentions mm ON m.id = mm.message_id
    INNER JOIN pin_messages p ON m.id = p.message_id
    """
    
    public func messageItems(conversationId: String) -> [MessageItem] {
        let sql = """
        \(Self.messageItemQuery)
        WHERE m.category != 'MESSAGE_RECALL' AND m.conversation_id = ?
        ORDER BY m.created_at ASC
        """
        return db.select(with: sql, arguments: [conversationId])
    }
    
    public func messageItem(messageId: String) -> MessageItem? {
        let sql = """
        \(Self.messageItemQuery)
        WHERE m.category != 'MESSAGE_RECALL' AND m.message_id = ?
        """
        return db.select(with: sql, arguments: [messageId])
    }
    
    
    public func lastPinnedMessage(conversationId: String) -> MessageItem? {
        let sql = """
        \(Self.messageItemQuery)
        WHERE m.category != 'MESSAGE_RECALL' AND m.conversation_id = ?
        ORDER BY p.created_at DESC
        LIMIT 1
        """
        return db.select(with: sql, arguments: [conversationId])
    }
    
    @discardableResult
    public func unpinMessage(messageId: String, conversationId: String) -> Bool {
        db.write { (db) in
            let deletedCount = try PinMessage
                .filter(PinMessage.column(of: .messageId) == messageId)
                .deleteAll(db)
            guard deletedCount > 0 else {
                return
            }
            db.afterNextTransactionCommit { db in
                let userInfo: [String: Any] = [
                    PinMessageDAO.UserInfoKey.conversationId: conversationId,
                    PinMessageDAO.UserInfoKey.messageId: messageId,
                    PinMessageDAO.UserInfoKey.isPinned: false
                ]
                NotificationCenter.default.post(onMainThread: PinMessageDAO.pinMessageDidChangeNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
    }
    @discardableResult
    public func pinMessage(item: MessageItem,
                           source: String,
                           silentNotification: Bool,
                           message: Message,
                           mention: MessageMention? = nil) -> Bool {
        let pinMessage = PinMessage(messageId: item.messageId, conversationId: item.conversationId, createdAt: message.createdAt)
        return db.write { db in
            try pinMessage.save(db)
            try mention?.save(db)
            try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: source, silentNotification: silentNotification)
            db.afterNextTransactionCommit { db in
                let userInfo: [String: Any] = [
                    PinMessageDAO.UserInfoKey.conversationId: item.conversationId,
                    PinMessageDAO.UserInfoKey.messageId: item.messageId,
                    PinMessageDAO.UserInfoKey.isPinned: true,
                    PinMessageDAO.UserInfoKey.message: item
                ]
                NotificationCenter.default.post(onMainThread: PinMessageDAO.pinMessageDidChangeNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
    }
    
    @discardableResult
    public func removeAllMessages(conversationId: String) -> Bool {
        db.write { db in
            try PinMessage.deleteAll(db)
        }
    }
    
    public func messageCount(conversationId: String) -> Int {
        db.count(in: PinMessage.self,
                 where: PinMessage.column(of: .conversationId) == conversationId)
    }
    
    public func hasMessages(conversationId: String) -> Bool {
        messageCount(conversationId: conversationId) > 0
    }
    
    public func isPinned(messageId: String) -> Bool {
        db.recordExists(in: PinMessage.self,
                        where: PinMessage.column(of: .messageId) == messageId)
    }
    
}
