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
    
    public func messageIds(transcriptId: String) -> [String] {
        db.select(column: TranscriptMessage.column(of: .messageId),
                  from: TranscriptMessage.self,
                  where: TranscriptMessage.column(of: .transcriptId) == transcriptId)
    }
    
    public func update(
        transcriptId: String,
        messageId: String,
        content: String?,
        mediaKey: Data?,
        mediaDigest: Data?,
        mediaStatus: String?,
        mediaCreatedAt: String?
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
