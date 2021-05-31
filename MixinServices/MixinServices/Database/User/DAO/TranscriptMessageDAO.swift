import GRDB

public final class TranscriptMessageDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let transcriptId = "tid"
        public static let messageId = "mid"
        public static let mediaStatus = "ms"
        public static let mediaUrl = "mu"
    }
    
    public static let shared = TranscriptMessageDAO()
    
    public static let mediaStatusDidUpdateNotification = Notification.Name("one.mixin.services.TranscriptMessageDAO.MediaStatusDidUpdate")
    
    public func transcriptMessages(transcriptId: String) -> [TranscriptMessage] {
        db.select(where: TranscriptMessage.column(of: .transcriptId) == transcriptId,
                  order: [TranscriptMessage.column(of: .createdAt)])
    }
    
    public func messageItems(transcriptId: String) -> [MessageItem] {
        let sql = """
            SELECT m.message_id AS id, '' AS conversation_id, m.user_id, m.category, m.content, m.media_url,
                m.media_mime_type, m.media_size, m.media_duration, m.media_width, m.media_height, NULL AS media_hash,
                m.media_key, m.media_digest, m.media_status, m.media_waveform, NULL AS media_local_id, m.thumb_image,
                m.thumb_url, 'READ' AS status, NULL AS participant_id, NULL AS snapshot_id, m.media_name AS name,
                m.sticker_id, m.created_at, IFNULL(u.full_name, m.user_full_name) as userFullName,
                u.identity_number as userIdentityNumber, u.avatar_url as userAvatarUrl,
                u.app_id as appId, NULL AS participantFullName, NULL AS participantUserId, NULL AS snapshotAmount,
                NULL AS snapshotAssetId, NULL AS snapshotType, NULL AS assetSymbol, NULL AS assetIcon,
                st.asset_width as assetWidth, st.asset_height as assetHeight, st.asset_url as assetUrl,
                st.asset_type as assetType, alb.category as assetCategory, NULL AS actionName,
                m.shared_user_id as sharedUserId, su.full_name as sharedUserFullName,
                su.identity_number as sharedUserIdentityNumber, su.avatar_url as sharedUserAvatarUrl,
                su.app_id as sharedUserAppId, su.is_verified as sharedUserIsVerified, m.quote_id AS quote_message_id,
                m.quote_content, m.mentions, 1 AS hasMentionRead
            FROM transcript_messages m
            LEFT JOIN users u ON m.user_id = u.user_id
            LEFT JOIN stickers st ON m.sticker_id = st.sticker_id
            LEFT JOIN albums alb ON alb.album_id = (
                SELECT album_id FROM sticker_relationships sr WHERE sr.sticker_id = m.sticker_id LIMIT 1
            )
            LEFT JOIN users su ON m.shared_user_id = su.user_id
            WHERE m.transcript_id = ?
        """
        return db.select(with: sql, arguments: [transcriptId])
    }
    
    public func messageIds(transcriptId: String) -> [String] {
        db.select(column: TranscriptMessage.column(of: .messageId),
                  from: TranscriptMessage.self,
                  where: TranscriptMessage.column(of: .transcriptId) == transcriptId)
    }
    
    public func hasTranscriptMessage(withMessageId id: String) -> Bool {
        db.recordExists(in: TranscriptMessage.self,
                        where: TranscriptMessage.column(of: .messageId) == id)
    }
    
    public func update(
        transcriptId: String,
        messageId: String,
        content: String,
        mediaKey: Data,
        mediaDigest: Data,
        mediaStatus: String,
        mediaCreatedAt: String
    ) {
        let assignments = [
            TranscriptMessage.column(of: .content).set(to: content),
            TranscriptMessage.column(of: .mediaKey).set(to: mediaKey),
            TranscriptMessage.column(of: .mediaDigest).set(to: mediaDigest),
            TranscriptMessage.column(of: .mediaStatus).set(to: mediaStatus),
            TranscriptMessage.column(of: .mediaCreatedAt).set(to: mediaCreatedAt),
        ]
        let condition = TranscriptMessage.column(of: .transcriptId) == transcriptId
            && TranscriptMessage.column(of: .messageId) == messageId
        db.update(TranscriptMessage.self, assignments: assignments, where: condition)
    }
    
    public func update(
        transcriptId: String,
        messageId: String,
        mediaStatus: MediaStatus,
        mediaUrl: String?
    ) {
        db.write { db in
            let updateCondition = TranscriptMessage.column(of: .transcriptId) == transcriptId
                && TranscriptMessage.column(of: .messageId) == messageId
            let assignments = [
                TranscriptMessage.column(of: .mediaStatus).set(to: mediaStatus.rawValue),
                TranscriptMessage.column(of: .mediaUrl).set(to: mediaUrl),
            ]
            try TranscriptMessage.filter(updateCondition).updateAll(db, assignments)
            
            var mediaStatusChangedConversationId: String?
            let categories = TranscriptMessage.Category.attachmentIncludedCategories.map(\.rawValue)
            let unfinishedChildCondition = TranscriptMessage.column(of: .transcriptId) == transcriptId
                && categories.contains(TranscriptMessage.column(of: .category))
                && TranscriptMessage.column(of: .mediaStatus) != MediaStatus.DONE.rawValue
            let unfinishedChild: Int? = try TranscriptMessage.select(Column.rowID).filter(unfinishedChildCondition).fetchOne(db)
            if unfinishedChild == nil {
                let changes = try Message
                    .filter(Message.column(of: .messageId) == transcriptId)
                    .updateAll(db, [Message.column(of: .mediaStatus).set(to: MediaStatus.DONE.rawValue)])
                if changes > 0 {
                    mediaStatusChangedConversationId = try Message
                        .select(Message.column(of: .conversationId))
                        .filter(Message.column(of: .messageId) == transcriptId)
                        .fetchOne(db)
                }
            }
            
            db.afterNextTransactionCommit { _ in
                let userInfo: [String : Any] = [
                    Self.UserInfoKey.transcriptId: transcriptId,
                    Self.UserInfoKey.messageId: messageId,
                    Self.UserInfoKey.mediaStatus: mediaStatus,
                    Self.UserInfoKey.mediaUrl: mediaUrl
                ]
                NotificationCenter.default.post(onMainThread: Self.mediaStatusDidUpdateNotification,
                                                object: self,
                                                userInfo: userInfo)
                if let conversationId = mediaStatusChangedConversationId {
                    let change = ConversationChange(conversationId: conversationId,
                                                    action: .updateMediaStatus(messageId: transcriptId, mediaStatus: .DONE))
                    NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
                }
            }
        }
    }
    
}
