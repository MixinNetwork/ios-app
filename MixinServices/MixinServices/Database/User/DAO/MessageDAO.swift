import UIKit
import GRDB

public final class MessageDAO: UserDatabaseDAO {
    
    public enum LocalMessageSource {
        public static let peerCall = "pc"
        public static let groupCall = "gc"
        public static let callService = "cs"
        public static let sendMessage = "sm"
        public static let transfer = "tr"
        public static let notificationServiceExtension = "nse"
        public static let shareExtension = "se"
    }
    
    public enum UserInfoKey {
        public static let conversationId = "conv_id"
        public static let message = "msg"
        public static let messageId = "mid"
        public static let messsageSource = "msg_source"
        public static let mediaStatus = "ms"
        public static let silentNotification = "sn"
    }
    
    public static let shared = MessageDAO()
    
    public static let willDeleteMessageNotification = Notification.Name("one.mixin.services.MessageDAO.willDeleteMessage")
    public static let didInsertMessageNotification = Notification.Name("one.mixin.services.did.insert.msg")
    public static let didRedecryptMessageNotification = Notification.Name("one.mixin.services.did.redecrypt.msg")
    public static let messageMediaStatusDidUpdateNotification = Notification.Name("one.mixin.services.MessageDAO.MessageMediaStatusDidUpdate")
    
    static let sqlQueryLastUnreadMessageTime = """
        SELECT created_at FROM messages
        WHERE conversation_id = ? AND status = 'DELIVERED' AND user_id != ?
        ORDER BY created_at DESC
        LIMIT 1
    """
    static let sqlQueryFullMessage = """
    SELECT m.id, m.conversation_id, m.user_id, m.category, m.content, m.media_url, m.media_mime_type,
            m.media_size, m.media_duration, m.media_width, m.media_height, m.media_hash, m.media_key,
            m.media_digest, m.media_status, m.media_waveform, m.thumb_image, m.thumb_url, m.status, m.participant_id, m.snapshot_id, m.name,
            m.sticker_id, m.created_at,
        u.full_name as userFullName, u.identity_number as userIdentityNumber, u.avatar_url as userAvatarUrl,
        u.app_id as appId, u.membership as userMembership,
        u1.full_name as participantFullName, u1.user_id as participantUserId,
        COALESCE(a.icon_url, t.icon_url) AS token_icon, COALESCE(a.name, t.name) AS token_name, COALESCE(a.symbol, t.symbol) AS token_symbol,
        t.collection_hash AS token_collection_hash,
        COALESCE(s.amount, ss.amount) AS snapshot_amount, COALESCE(s.asset_id, ss.asset_id) AS snapshot_asset_id, COALESCE(s.type, ss.type) AS snapshot_type, COALESCE(s.memo, ss.memo) AS snapshot_memo,
        st.asset_width as assetWidth, st.asset_height as assetHeight, st.asset_url as assetUrl, st.asset_type as assetType, alb.category as assetCategory,
        m.action as actionName, m.shared_user_id as sharedUserId,
        su.full_name as sharedUserFullName, su.identity_number as sharedUserIdentityNumber, 
        su.avatar_url as sharedUserAvatarUrl, su.app_id as sharedUserAppId,
        su.is_verified as sharedUserIsVerified, su.membership as sharedUserMembership,
        m.quote_message_id, m.quote_content,
        mm.mentions, mm.has_read as hasMentionRead,
        CASE WHEN (SELECT 1 FROM pin_messages WHERE message_id = m.id) IS NULL THEN 0 ELSE 1 END AS pinned,
        alb.added as isStickerAdded, m.album_id, em.expire_in as expire_in
    FROM messages m
    LEFT JOIN users u ON m.user_id = u.user_id
    LEFT JOIN users u1 ON m.participant_id = u1.user_id
    LEFT JOIN snapshots s ON m.snapshot_id = s.snapshot_id
    LEFT JOIN safe_snapshots ss ON m.snapshot_id = ss.snapshot_id
    LEFT JOIN assets a ON s.asset_id = a.asset_id
    LEFT JOIN tokens t ON ss.asset_id = t.asset_id
    LEFT JOIN stickers st ON m.sticker_id = st.sticker_id
    LEFT JOIN albums alb ON alb.album_id = (
        SELECT album_id FROM sticker_relationships sr WHERE sr.sticker_id = m.sticker_id LIMIT 1
    )
    LEFT JOIN users su ON m.shared_user_id = su.user_id
    LEFT JOIN message_mentions mm ON m.id = mm.message_id
    LEFT JOIN expired_messages em ON m.id = em.message_id
    """
    private static let sqlQueryFirstNMessages = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ?
    ORDER BY m.created_at ASC
    LIMIT ?
    """
    private static let sqlQueryLastNMessages = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ?
    ORDER BY m.created_at DESC
    LIMIT ?
    """
    static let sqlQueryFullAudioMessages = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ? AND m.category in ('SIGNAL_AUDIO', 'PLAIN_AUDIO', 'ENCRYPTED_AUDIO')
    """
    static let sqlQueryFullDataMessages = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ? AND m.category in ('SIGNAL_DATA', 'PLAIN_DATA', 'ENCRYPTED_DATA')
    """
    static let sqlQueryFullMessageById = sqlQueryFullMessage + " WHERE m.id = ?"
    static let sqlQueryQuoteMessageById = """
    \(sqlQueryFullMessage)
    WHERE m.id = ? AND m.status <> 'FAILED'
    """
    private static let sqlUpdateOldStickers = """
    UPDATE messages SET sticker_id = (
        SELECT s.sticker_id FROM stickers s
        INNER JOIN sticker_relationships sa ON sa.sticker_id = s.sticker_id
        INNER JOIN albums a ON a.album_id = sa.album_id
        WHERE a.album_id = messages.album_id AND s.name = messages.name
    ) WHERE category LIKE '%_STICKER' AND ifnull(sticker_id, '') = ''
    """
    private static let sqlUpdateUnseenMessageCount = """
    UPDATE conversations SET unseen_message_count = (
        SELECT count(*) FROM messages
        WHERE conversation_id = ? AND status = 'DELIVERED' AND user_id != ?
    ) WHERE conversation_id = ?
    """
    
    private let updateMediaStatusQueue = DispatchQueue(label: "one.mixin.services.queue.media.status.queue")
    
    public func getMediaUrls(categories: [MessageCategory]) -> [String] {
        db.select(column: Message.column(of: .mediaUrl),
                  from: Message.self,
                  where: categories.map(\.rawValue).contains(Message.column(of: .category)))
    }
    
    public func getMediaUrls(conversationId: String, categories: [MessageCategory]) -> [String: String] {
        let condition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
            && categories.map(\.rawValue).contains(Message.column(of: .category))
        return db.select(keyColumn: Message.column(of: .mediaUrl),
                         valueColumn: Message.column(of: .category),
                         from: Message.self,
                         where: condition)
    }
    
    public func getTranscriptMessageIds(conversationId: String, database: GRDB.Database) throws -> [String] {
        let categories = [
            MessageCategory.SIGNAL_TRANSCRIPT.rawValue,
            MessageCategory.PLAIN_TRANSCRIPT.rawValue,
            MessageCategory.ENCRYPTED_TRANSCRIPT.rawValue
        ]
        let condition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
            && categories.contains(Message.column(of: .category))
        return try Message
            .select(Message.column(of: .messageId))
            .filter(condition)
            .order(Message.column(of: .createdAt).asc)
            .fetchAll(database)
    }
    
    public func getDownloadedMediaUrls(categories: [MessageCategory], offset: Int, limit: Int) -> [String: String] {
        let condition: SQLSpecificExpressible = categories.map(\.rawValue).contains(Message.column(of: .category))
            && Message.column(of: .mediaStatus) == MediaStatus.DONE.rawValue
        return db.select(keyColumn: Message.column(of: .messageId),
                         valueColumn: Message.column(of: .mediaUrl),
                         from: Message.self,
                         where: condition,
                         order: [Message.column(of: .createdAt).desc],
                         offset: offset,
                         limit: limit)
    }
    
    public func getUnreadMessages(conversationId: String) -> [UnreadMessage] {
        let sql = """
            SELECT m.id, em.expire_in, em.expire_at
            FROM messages m
            LEFT JOIN expired_messages em ON m.id = em.message_id
            WHERE m.conversation_id = ? AND m.status = ? AND m.user_id != ? AND m.created_at >= ifnull(
                (
                    SELECT m.created_at
                    FROM conversations c
                    LEFT JOIN messages m ON c.last_read_message_id = m.id
                    WHERE c.conversation_id = ?
                ),
                (
                    ''
                )
            )
            ORDER BY m.created_at ASC
        """
        return db.select(with: sql, arguments: [conversationId, MessageStatus.DELIVERED.rawValue, myUserId, conversationId])
    }
    
    public func deleteMediaMessages(conversationId: String, categories: [MessageCategory]) {
        let condition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
            && categories.map(\.rawValue).contains(Message.column(of: .category))
        db.write { db in
            let messageIds: [String] = try Message
                .select(Message.column(of: .messageId))
                .filter(condition)
                .fetchAll(db)
            try Message.filter(condition).deleteAll(db)
            try ConversationDAO.shared.updateLastMessageIdOnDeleteMessage(conversationId: conversationId, database: db)
            try PinMessageDAO.shared.delete(messageIds: messageIds, conversationId: conversationId, from: db)
            try clearPinMessageContent(quoteMessageIds: messageIds, conversationId: conversationId, from: db)
        }
    }
    
    public func findFailedMessages(conversationId: String, userId: String) -> [String] {
        let condition = Message.column(of: .conversationId) == conversationId
            && Message.column(of: .userId) == userId
            && Message.column(of: .status) == MessageStatus.FAILED.rawValue
        return db.select(column: Message.column(of: .messageId),
                         from: Message.self,
                         where: condition,
                         order: [Message.column(of: .createdAt).desc],
                         limit: 1000)
    }
    
    public func updateMessageContentAndMediaStatus(content: String, mediaStatus: MediaStatus, key: Data?, digest: Data?, messageId: String, conversationId: String) {
        let assignments = [
            Message.column(of: .content).set(to: content),
            Message.column(of: .mediaStatus).set(to: mediaStatus.rawValue),
            Message.column(of: .mediaKey).set(to: key),
            Message.column(of: .mediaDigest).set(to: digest)
        ]
        let condition: SQLSpecificExpressible = Message.column(of: .messageId) == messageId
            && Message.column(of: .category) != MessageCategory.MESSAGE_RECALL.rawValue
        db.update(Message.self, assignments: assignments, where: condition) { _ in
            let mediaStatusUserInfo: [String: Any] = [
                UserInfoKey.messageId: messageId,
                UserInfoKey.mediaStatus: mediaStatus
            ]
            NotificationCenter.default.post(onMainThread: Self.messageMediaStatusDidUpdateNotification,
                                            object: self,
                                            userInfo: mediaStatusUserInfo)
            
            let keyChange = ConversationChange(conversationId: conversationId,
                                            action: .updateMediaKey(messageId: messageId, content: content, key: key, digest: digest))
            NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: keyChange)
        }
    }
    
    public func update(content: String, forMessageWith messageId: String) {
        db.write { db in
            let changesCount = try Message
                .filter(Message.column(of: .messageId) == messageId && Message.column(of: .category) != MessageCategory.MESSAGE_RECALL.rawValue)
                .updateAll(db, [Message.column(of: .content).set(to: content)])
            let conversationID: String? = try Message.select(Message.column(of: .conversationId))
                .filter(Message.column(of: .messageId) == messageId)
                .fetchOne(db)
            if changesCount != 0, let conversationID {
                db.afterNextTransaction { _ in
                    DispatchQueue.main.async {
                        let change = ConversationChange(
                            conversationId: conversationID,
                            action: .updateMessage(messageId: messageId)
                        )
                        NotificationCenter.default.post(name: conversationDidChangeNotification, object: change)
                    }
                }
            }
        }
    }
    
    public func update(quoteContent: Data, for messageId: String) {
        db.update(Message.self,
                  assignments: [Message.column(of: .quoteContent).set(to: quoteContent)],
                  where: Message.column(of: .messageId) == messageId)
    }
    
    public func isExist(messageId: String) -> Bool {
        db.recordExists(in: Message.self, where: Message.column(of: .messageId) == messageId)
    }
    
    public func batchUpdateMessageStatus(readMessageIds: [String], mentionMessageIds: [String]) {
        var readMessageIds = readMessageIds
        var readMessages: [Message] = []
        var mentionMessages: [Message] = []
        var conversationIds: Set<String> = []
        
        if readMessageIds.count > 0 {
            let condition: SQLSpecificExpressible = readMessageIds.contains(Message.column(of: .messageId))
                && Message.column(of: .status) != MessageStatus.FAILED.rawValue
                && Message.column(of: .status) != MessageStatus.READ.rawValue
            readMessages = db.select(where: condition)
            readMessageIds = readMessages.map { $0.messageId }
            
            conversationIds = Set<String>(readMessages.map { $0.conversationId })
        }
        
        if mentionMessageIds.count > 0 {
            let condition: SQLSpecificExpressible = mentionMessageIds.contains(Message.column(of: .messageId))
                && Message.column(of: .status) != MessageStatus.FAILED.rawValue
            mentionMessages = db.select(where: condition)
        }
        
        db.write { (db) in
            if readMessageIds.count > 0 {
                try Message
                    .filter(readMessageIds.contains(Message.column(of: .messageId)))
                    .updateAll(db, [Message.column(of: .status).set(to: MessageStatus.READ.rawValue)])
                for conversationId in conversationIds {
                    try MessageDAO.shared.updateUnseenMessageCount(database: db, conversationId: conversationId)
                }
            }
            
            if mentionMessageIds.count > 0 {
                try MessageMention
                    .filter(mentionMessageIds.contains(MessageMention.column(of: .messageId)))
                    .updateAll(db, [MessageMention.column(of: .hasRead).set(to: true)])
            }
            
            if !isAppExtension {
                db.afterNextTransaction { (_) in
                    for message in readMessages {
                        let change = ConversationChange(conversationId: message.conversationId, action: .updateMessageStatus(messageId: message.messageId, newStatus: .READ))
                        NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
                    }
                    for message in mentionMessages {
                        let change = ConversationChange(conversationId: message.conversationId, action: .updateMessageMentionStatus(messageId: message.messageId, newStatus: .MENTION_READ))
                        NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
                    }
                }
            }
        }
        
        guard !isAppExtension else {
            return
        }
        NotificationCenter.default.post(name: MixinService.messageReadStatusDidChangeNotification, object: self)
        UNUserNotificationCenter.current().removeNotifications(withIdentifiers: readMessageIds)
        UNUserNotificationCenter.current().removeNotifications(withIdentifiers: mentionMessageIds)
    }
    
    public func updateMessageStatus(messageId: String, status: String, from: String) {
        guard let oldMessage: Message = db.select(where: Message.column(of: .messageId) == messageId) else {
            return
        }
        guard oldMessage.status != MessageStatus.FAILED.rawValue else {
            let error = MixinServicesError.badMessageData(id: messageId, status: status, from: from)
            reporter.report(error: error)
            return
        }
        guard MessageStatus.getOrder(messageStatus: status) > MessageStatus.getOrder(messageStatus: oldMessage.status) else {
            return
        }
        
        let conversationId = oldMessage.conversationId
        
        let completion: ((GRDB.Database) -> Void)?
        if isAppExtension {
            completion = nil
        } else {
            completion = { _ in
                let status = MessageStatus(rawValue: status) ?? .UNKNOWN
                let change = ConversationChange(conversationId: conversationId,
                                                action: .updateMessageStatus(messageId: messageId, newStatus: status))
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
            }
        }
        
        db.write { db in
            try Message
                .filter(Message.column(of: .messageId) == messageId)
                .updateAll(db, [Message.column(of: .status).set(to: status)])
            if status == MessageStatus.SENT.rawValue {
                try ExpiredMessageDAO.shared.updateExpireAt(for: messageId, database: db, postNotification: true)
            }
            if let completion = completion {
                db.afterNextTransaction(onCommit: completion)
            }
        }
    }
    
    public func updateUnseenMessageCount(database: GRDB.Database, conversationId: String) throws {
        try database.execute(sql: Self.sqlUpdateUnseenMessageCount,
                             arguments: [conversationId, myUserId, conversationId])
    }
    
    @discardableResult
    public func updateMediaMessage(messageId: String, assignments: [ColumnAssignment], completion: Database.Completion? = nil) -> Bool {
        let condition = Message.column(of: .messageId) == messageId
            && Message.column(of: .category) != MessageCategory.MESSAGE_RECALL.rawValue
        return db.update(Message.self,
                         assignments: assignments,
                         where: condition,
                         completion: completion)
    }
    
    public func updateMediaMessage(messageId: String, mediaUrl: String, status: MediaStatus, conversationId: String, content: String? = nil) {
        var assignments = [
            Message.column(of: .mediaUrl).set(to: mediaUrl),
            Message.column(of: .mediaStatus).set(to: status.rawValue)
        ]
        if let content = content {
            assignments.append(Message.column(of: .content).set(to: content))
        }
        let condition: SQLSpecificExpressible = Message.column(of: .messageId) == messageId
            && Message.column(of: .category) != MessageCategory.MESSAGE_RECALL.rawValue
        db.update(Message.self, assignments: assignments, where: condition) { _ in
            let change = ConversationChange(conversationId: conversationId,
                                            action: .updateMessage(messageId: messageId))
            NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
        }
    }
    
    public func updateMediaStatus(messageId: String, status: MediaStatus, conversationId: String) {
        let targetStatus = status
        updateMediaStatusQueue.async {
            self.db.write { (db) in
                let request = try Message
                    .select(Message.column(of: .mediaStatus))
                    .filter(Message.column(of: .messageId) == messageId)
                let oldStatus = try String.fetchOne(db, request)
                
                guard oldStatus != targetStatus.rawValue else {
                    return
                }
                if (targetStatus == .PENDING || targetStatus == .CANCELED) && oldStatus == MediaStatus.DONE.rawValue {
                    return
                }
                
                let updateCondition: SQLSpecificExpressible = Message.column(of: .messageId) == messageId
                    && Message.column(of: .category) != MessageCategory.MESSAGE_RECALL.rawValue
                let numberOfChanges = try Message
                    .filter(updateCondition)
                    .updateAll(db, [Message.column(of: .mediaStatus).set(to: targetStatus.rawValue)])
                if numberOfChanges > 0 {
                    let userInfo: [String: Any] = [
                        UserInfoKey.messageId: messageId,
                        UserInfoKey.mediaStatus: status
                    ]
                    NotificationCenter.default.post(onMainThread: Self.messageMediaStatusDidUpdateNotification,
                                                    object: self,
                                                    userInfo: userInfo)
                }
            }
        }
    }
    
    public func updateMessageCategory(_ category: String, forMessageWithId id: String) {
        db.update(Message.self,
                  assignments: [Message.column(of: .category).set(to: category)],
                  where: Message.column(of: .messageId) == id)
    }
    
    public func getFullMessage(messageId: String) -> MessageItem? {
        db.select(with: MessageDAO.sqlQueryFullMessageById, arguments: [messageId])
    }
    
    public func getFullMessages(messageIds: [String], with database: GRDB.Database) throws -> [MessageItem] {
        guard !messageIds.isEmpty else {
            return []
        }
        let ids = messageIds.joined(separator: "', '")
        let sql = """
        \(Self.sqlQueryFullMessage)
        WHERE m.id in ('\(ids)')
        """
        return try MessageItem.fetchAll(database, sql: sql)
    }
    
    public func getMessage(messageId: String) -> Message? {
        db.select(where: Message.column(of: .messageId) == messageId)
    }
    
    public func getMessage(messageId: String, userId: String) -> Message? {
        let condition: SQLSpecificExpressible = Message.column(of: .messageId) == messageId
            && Message.column(of: .userId) == userId
        return db.select(where: condition)
    }
    
    public func firstUnreadMessage(conversationId: String) -> Message? {
        guard hasUnreadMessage(conversationId: conversationId) else {
            return nil
        }
        let myLastMessage: Message? = {
            let sql = """
            SELECT *
            FROM messages INDEXED BY index_messages_pick
            WHERE conversation_id = ?
                AND status IN (?, ?, ?, ?)
                AND user_id = ?
            ORDER BY created_at DESC
            LIMIT 1
            """
            let arguments: StatementArguments = [
                conversationId,
                MessageStatus.SENDING.rawValue,
                MessageStatus.DELIVERED.rawValue,
                MessageStatus.SENT.rawValue,
                MessageStatus.READ.rawValue,
                myUserId
            ]
            return db.select(with: sql, arguments: arguments)
        }()
        let lastReadCondition: SQLSpecificExpressible
        if let myLastMessage = myLastMessage {
            lastReadCondition = Message.column(of: .conversationId) == conversationId
                && Message.column(of: .status) == MessageStatus.READ.rawValue
                && Message.column(of: .category) != MessageCategory.SYSTEM_CONVERSATION.rawValue
                && Message.column(of: .userId) != myUserId
                && Message.column(of: .createdAt) > myLastMessage.createdAt
        } else {
            lastReadCondition = Message.column(of: .conversationId) == conversationId
                && Message.column(of: .status) == MessageStatus.READ.rawValue
                && Message.column(of: .category) != MessageCategory.SYSTEM_CONVERSATION.rawValue
                && Message.column(of: .userId) != myUserId
        }
        let lastReadMessage: Message? = db.select(where: lastReadCondition, order: [Message.column(of: .createdAt).desc])
        let firstUnreadCondition: SQLSpecificExpressible
        if let lastReadMessage = lastReadMessage {
            firstUnreadCondition = Message.column(of: .conversationId) == conversationId
                && Message.column(of: .status) == MessageStatus.DELIVERED.rawValue
                && Message.column(of: .userId) != myUserId
                && Message.column(of: .createdAt) > lastReadMessage.createdAt
        } else if let myLastMessage = myLastMessage {
            firstUnreadCondition = Message.column(of: .conversationId) == conversationId
                && Message.column(of: .status) == MessageStatus.DELIVERED.rawValue
                && Message.column(of: .userId) != myUserId
                && Message.column(of: .createdAt) > myLastMessage.createdAt
        } else {
            firstUnreadCondition = Message.column(of: .conversationId) == conversationId
                && Message.column(of: .status) == MessageStatus.DELIVERED.rawValue
                && Message.column(of: .userId) != myUserId
        }
        return db.select(where: firstUnreadCondition,
                         order: [Message.column(of: .createdAt).asc])
    }
    
    public typealias MessagesResult = (messages: [MessageItem], didReachBegin: Bool, didReachEnd: Bool)
    public func getMessages(conversationId: String, aroundMessageId messageId: String, count: Int) -> MessagesResult? {
        guard let message = getFullMessage(messageId: messageId) else {
            return nil
        }
        let aboveCount = 10
        let belowCount = count - aboveCount
        let messagesAbove = getMessages(conversationId: conversationId, aboveMessage: message, count: aboveCount)
        let messagesBelow = getMessages(conversationId: conversationId, belowMessage: message, count: belowCount)
        var messages = [MessageItem]()
        messages.append(contentsOf: messagesAbove)
        messages.append(message)
        messages.append(contentsOf: messagesBelow)
        return (messages, messagesAbove.count < aboveCount, messagesBelow.count < belowCount)
    }
    
    public func getMessages(conversationId: String, aboveMessage location: MessageItem, count: Int) -> [MessageItem] {
        let sql = """
        \(Self.sqlQueryFullMessage)
        WHERE m.conversation_id = ? AND m.created_at <= ? AND m.id != ?
        ORDER BY m.created_at DESC, m.ROWID DESC
        LIMIT ?
        """
        return db.select(with: sql, arguments: [conversationId, location.createdAt, location.messageId, count]).reversed()
    }
    
    public func getMessages(conversationId: String, belowMessage location: MessageItem, count: Int) -> [MessageItem] {
        let sql = """
        \(Self.sqlQueryFullMessage)
        WHERE m.conversation_id = ? AND m.created_at >= ? AND m.id != ?
        ORDER BY m.created_at ASC, m.ROWID ASC
        LIMIT ?
        """
        return db.select(with: sql, arguments: [conversationId, location.createdAt, location.messageId, count])
    }
    
    public func getMessages(conversationId: String, categoryIn categories: [MessageCategory], earlierThan location: MessageItem?, count: Int) -> [MessageItem] {
        let categories = categories.map(\.rawValue).joined(separator: "', '")
        var sql = """
        \(Self.sqlQueryFullMessage)
        WHERE m.conversation_id = ? AND m.category in ('\(categories)')
        """
        if let location {
            sql += " AND m.created_at <= '\(location.createdAt)' AND m.id != '\(location.messageId)'"
        }
        sql += " ORDER BY m.created_at DESC, m.ROWID DESC LIMIT ?"
        return db.select(with: sql, arguments: [conversationId, count])
    }
    
    public func getFirstNMessages(conversationId: String, count: Int) -> [MessageItem] {
        db.select(with: MessageDAO.sqlQueryFirstNMessages, arguments: [conversationId, count])
    }
    
    public func getLastNMessages(conversationId: String, count: Int) -> [MessageItem] {
        let messages: [MessageItem] = db.select(with: MessageDAO.sqlQueryLastNMessages, arguments: [conversationId, count])
        return messages.reversed()
    }
    
    public func getInvitationMessage(conversationId: String, inviteeUserId: String) -> Message? {
        let condition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
            && Message.column(of: .category) == MessageCategory.SYSTEM_CONVERSATION.rawValue
            && Message.column(of: .action) == SystemConversationAction.ADD.rawValue
            && Message.column(of: .participantId) == inviteeUserId
        return db.select(where: condition, order: [Message.column(of: .createdAt).asc])
    }
    
    public func getUnreadMessagesCount(conversationId: String) -> Int {
        guard let firstUnreadMessage = self.firstUnreadMessage(conversationId: conversationId) else {
            return 0
        }
        let condition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
            && Message.column(of: .createdAt) >= firstUnreadMessage.createdAt
        return db.count(in: Message.self, where: condition)
    }
    
    public func getNonFailedMessage(messageId: String) -> MessageItem? {
        guard !messageId.isEmpty else {
            return nil
        }
        return db.select(with: MessageDAO.sqlQueryQuoteMessageById, arguments: [messageId])
    }
    
    public func insertMessage(
        message: Message,
        children: [TranscriptMessage]? = nil,
        messageSource: String,
        silentNotification: Bool = false,
        expireIn: Int64 = 0,
        completion: (() -> Void)? = nil
    ) {
        if expireIn != 0
           && message.userId == myUserId
           && -Int64(message.createdAt.toUTCDate().timeIntervalSinceNow) >= expireIn {
            return
        }
        var message = message
        
        let quotedMessage: MessageItem?
        if let id = message.quoteMessageId, let quoted = getNonFailedMessage(messageId: id) {
            
            // Prevent recursion of quoting
            quoted.quoteContent = nil
            quoted.quoteMessageId = nil
            
            message.quoteContent = try? JSONEncoder.default.encode(quoted)
            quotedMessage = quoted
        } else {
            quotedMessage = nil
        }
        
        db.write { (db) in
            if let mention = MessageMention(message: message, quotedMessage: quotedMessage) {
                try mention.save(db)
            }
            try children?.save(db)
            try insertMessage(database: db,
                              message: message,
                              children: children,
                              messageSource: messageSource,
                              silentNotification: silentNotification,
                              expireIn: expireIn,
                              completion: completion)
        }
    }
    
    public func insertMessage(
        database: GRDB.Database,
        message: Message,
        children: [TranscriptMessage]? = nil,
        messageSource: String,
        silentNotification: Bool,
        expireIn: Int64 = 0,
        completion: (() -> Void)? = nil
    ) throws {
        if message.category.hasPrefix("SIGNAL_") {
            try message.insert(database)
        } else {
            try message.save(database)
        }
        try ConversationDAO.shared.updateLastMessageIdOnInsertMessage(conversationId: message.conversationId,
                                                                      messageId: message.messageId,
                                                                      createdAt: message.createdAt,
                                                                      database: database)
        if expireIn != 0 && !message.category.hasPrefix("SYSTEM_") {
            let expireAt: Int64?
            if message.status == MessageStatus.SENT.rawValue || message.status == MessageStatus.READ.rawValue {
                expireAt = Int64(message.createdAt.toUTCDate().timeIntervalSince1970) + expireIn
            } else {
                expireAt = nil
            }
            let msg = ExpiredMessage(messageId: message.messageId, expireIn: expireIn, expireAt: expireAt)
            try ExpiredMessageDAO.shared.insert(message: msg, database: database)
        }
        let shouldInsertIntoFTSTable = AppGroupUserDefaults.Database.isFTSInitialized
            && message.status != MessageStatus.FAILED.rawValue
            && MessageCategory.ftsAvailableCategoryStrings.contains(message.category)
        if shouldInsertIntoFTSTable {
            try insertFTSContent(database, message: message, children: children)
        }
        try MessageDAO.shared.updateUnseenMessageCount(database: database, conversationId: message.conversationId)
        
        database.afterNextTransaction { (_) in
            // Dispatch to global queue to prevent deadlock
            // Inside the block there's a request to access reading pool, embedding it inside write
            // may causes deadlock
            DispatchQueue.global().async {
                if isAppExtension {
                    if AppGroupUserDefaults.isRunningInMainApp {
                        DarwinNotificationManager.shared.notifyConversationDidChangeInMainApp()
                    }
                    if AppGroupUserDefaults.User.currentConversationId == message.conversationId {
                        AppGroupUserDefaults.User.reloadConversation = true
                    }
                } else if let newMessage: MessageItem = try? self.db.select(with: MessageDAO.sqlQueryFullMessageById, arguments: [message.messageId]) {
                    let userInfo: [String: Any] = [
                        MessageDAO.UserInfoKey.conversationId: newMessage.conversationId,
                        MessageDAO.UserInfoKey.message: newMessage,
                        MessageDAO.UserInfoKey.messsageSource: messageSource,
                        MessageDAO.UserInfoKey.silentNotification: silentNotification,
                    ]
                    NotificationCenter.default.post(onMainThread: MessageDAO.didInsertMessageNotification, object: self, userInfo: userInfo)
                }
                completion?()
            }
        }
    }
    
    public func recallMessage(message: MessageItem) {
        let messageId = message.messageId
        ReceiveMessageService.shared.stopRecallMessage(item: message)
        
        let condition = Message.column(of: .conversationId) == message.conversationId
            && Message.column(of: .quoteMessageId) == messageId
        let quoteMessageIds: [String] = db.select(column: Message.column(of: .messageId),
                                                  from: Message.self,
                                                  where: condition)
        db.write { (db) in
            try self.recallMessage(database: db,
                                   messageId: message.messageId,
                                   conversationId: message.conversationId,
                                   category: message.category,
                                   status: message.status,
                                   quoteMessageIds: quoteMessageIds)
        }
    }
    
    public func recallMessage(database: GRDB.Database, messageId: String, conversationId: String, category: String, status: String, quoteMessageIds: [String]) throws {
        var assignments: [ColumnAssignment] = [
            Message.column(of: .category).set(to: MessageCategory.MESSAGE_RECALL.rawValue)
        ]
        
        if status == MessageStatus.UNKNOWN.rawValue || ["_TEXT", "_POST", "_LOCATION"].contains(where: category.hasSuffix(_:)) {
            assignments.append(Message.column(of: .content).set(to: nil))
            assignments.append(Message.column(of: .quoteMessageId).set(to: nil))
            assignments.append(Message.column(of: .quoteContent).set(to: nil))
        } else if ["_IMAGE", "_VIDEO", "_LIVE", "_DATA", "_AUDIO"].contains(where: category.hasSuffix) {
            assignments.append(Message.column(of: .content).set(to: nil))
            assignments.append(Message.column(of: .mediaUrl).set(to: nil))
            assignments.append(Message.column(of: .mediaStatus).set(to: nil))
            assignments.append(Message.column(of: .mediaMimeType).set(to: nil))
            assignments.append(Message.column(of: .mediaSize).set(to: 0))
            assignments.append(Message.column(of: .mediaDuration).set(to: 0))
            assignments.append(Message.column(of: .mediaWidth).set(to: 0))
            assignments.append(Message.column(of: .mediaHeight).set(to: 0))
            assignments.append(Message.column(of: .thumbImage).set(to: nil))
            assignments.append(Message.column(of: .thumbUrl).set(to: nil))
            assignments.append(Message.column(of: .mediaKey).set(to: nil))
            assignments.append(Message.column(of: .mediaDigest).set(to: nil))
            assignments.append(Message.column(of: .mediaWaveform).set(to: nil))
            assignments.append(Message.column(of: .name).set(to: nil))
        } else if category.hasSuffix("_STICKER") {
            assignments.append(Message.column(of: .stickerId).set(to: nil))
        } else if category.hasSuffix("_CONTACT") {
            assignments.append(Message.column(of: .sharedUserId).set(to: nil))
        }
        if status == MessageStatus.FAILED.rawValue {
            assignments.append(Message.column(of: .status).set(to: MessageStatus.DELIVERED.rawValue))
        }
        
        try Message
            .filter(Message.column(of: .messageId) == messageId)
            .updateAll(database, assignments)
        try MessageMention
            .filter(MessageMention.column(of: .messageId) == messageId)
            .deleteAll(database)
        try PinMessageDAO.shared.delete(messageIds: [messageId], conversationId: conversationId, from: database)
        try clearPinMessageContent(quoteMessageIds: [messageId], conversationId: conversationId, from: database)
        
        if category.hasSuffix("_TRANSCRIPT") {
            try TranscriptMessage
                .filter(TranscriptMessage.column(of: .transcriptId) == messageId)
                .deleteAll(database)
        }
        if let category = MessageCategory(rawValue: category) {
            if MessageCategory.ftsAvailable.contains(category) {
                try deleteFTSContent(database, messageId: messageId)
            }
        }
        
        if status == MessageStatus.FAILED.rawValue {
            try MessageDAO.shared.updateUnseenMessageCount(database: database, conversationId: conversationId)
        }
        
        
        if quoteMessageIds.count > 0, let quoteMessage = try MessageItem.fetchOne(database, sql: MessageDAO.sqlQueryQuoteMessageById, arguments: [messageId], adapter: nil), let data = try? JSONEncoder.default.encode(quoteMessage) {
            try Message
                .filter(quoteMessageIds.contains(Message.column(of: .messageId)))
                .updateAll(database, [Message.column(of: .quoteContent).set(to: data)])
        }
        
        let messageIds = quoteMessageIds + [messageId]
        database.afterNextTransaction { (_) in
            for messageId in messageIds {
                let change = ConversationChange(conversationId: conversationId,
                                                action: .recallMessage(messageId: messageId))
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
            }
        }
    }
    
    @discardableResult
    public func deleteMessage(id: String) -> (deleted: Bool, childMessageIds: [String]) {
        NotificationCenter.default.post(onMainThread: Self.willDeleteMessageNotification,
                                        object: self,
                                        userInfo: [UserInfoKey.messageId: id])
        var deleted = false
        var childMessageIds: [String] = []
        db.write { (db) in
            (deleted, childMessageIds) = try deleteMessage(id: id, with: db)
        }
        return (deleted, childMessageIds)
    }
    
    func deleteMessage(id: String, with database: GRDB.Database) throws -> (deleted: Bool, childMessageIds: [String]) {
        var deleteCount = 0
        var childMessageIds: [String] = []
        let conversationId: String? = try Message
            .select(Message.column(of: .conversationId))
            .filter(Message.column(of: .messageId) == id)
            .fetchOne(database)
        deleteCount = try Message
            .filter(Message.column(of: .messageId) == id)
            .deleteAll(database)
        if deleteCount > 0, let conversationId = conversationId {
            try ConversationDAO.shared.updateLastMessageIdOnDeleteMessage(conversationId: conversationId, messageId: id, database: database)
        }
        try MessageMention
            .filter(MessageMention.column(of: .messageId) == id)
            .deleteAll(database)
        try deleteFTSContent(database, messageId: id)
        childMessageIds = try TranscriptMessage
            .select(TranscriptMessage.column(of: .messageId))
            .filter(TranscriptMessage.column(of: .transcriptId) == id)
            .fetchAll(database)
        try TranscriptMessage
            .filter(TranscriptMessage.column(of: .transcriptId) == id)
            .deleteAll(database)
        if let conversationId = conversationId {
            try PinMessageDAO.shared.delete(messageIds: [id], conversationId: conversationId, from: database)
            try clearPinMessageContent(quoteMessageIds: [id], conversationId: conversationId, from: database)
        }
        return (deleteCount > 0, childMessageIds)
    }
    
    public func hasSentMessage(inConversationOf conversationId: String) -> Bool {
        let possibleStatus = [
            MessageStatus.SENDING.rawValue,
            MessageStatus.SENT.rawValue,
            MessageStatus.DELIVERED.rawValue,
            MessageStatus.READ.rawValue,
        ]
        let condition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
            && possibleStatus.contains(Message.column(of: .status)) // Make use of index_messages_pick
            && Message.column(of: .userId) == myUserId
        return db.recordExists(in: Message.self, where: condition)
    }
    
    public func hasMessage(id: String) -> Bool {
        db.recordExists(in: Message.self,
                        where: Message.column(of: .messageId) == id)
    }
    
    public func quoteMessageId(messageId: String) -> String? {
        db.select(column: Message.column(of: .quoteMessageId),
                  from: Message.self,
                  where: Message.column(of: .messageId) == messageId)
    }
    
}

extension MessageDAO {
    
    private func hasUnreadMessage(conversationId: String) -> Bool {
        let condition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
            && Message.column(of: .status) == MessageStatus.DELIVERED.rawValue
            && Message.column(of: .userId) != myUserId
        return db.recordExists(in: Message.self, where: condition)
    }
    
    private func updateRedecryptMessage(
        assignments: [ColumnAssignment],
        mention: MessageMention? = nil,
        messageId: String,
        category: String,
        conversationId: String,
        messageSource: String,
        children: [TranscriptMessage]? = nil,
        silentNotification: Bool
    ) {
        var newMessage: MessageItem?
        
        db.write { (db) in
            try mention?.save(db)
            let condition: SQLSpecificExpressible = Message.column(of: .messageId) == messageId
                && Message.column(of: .category) != MessageCategory.MESSAGE_RECALL.rawValue
            let changes = try Message.filter(condition).updateAll(db, assignments)
            if changes > 0 {
                try MessageDAO.shared.updateUnseenMessageCount(database: db, conversationId: conversationId)
                newMessage = try MessageItem.fetchOne(db, sql: MessageDAO.sqlQueryFullMessageById, arguments: [messageId], adapter: nil)
            }
            
            // isFTSInitialized is wrote inside a write block, checking it within a write block keeps the value in sync
            if MessageCategory.ftsAvailableCategoryStrings.contains(category), AppGroupUserDefaults.Database.isFTSInitialized, let item = newMessage {
                let message = Message.createMessage(message: item)
                try insertFTSContent(db, message: message, children: children)
            }
            
            try children?.save(db)
        }
        
        guard let message = newMessage else {
            return
        }
        let userInfo: [String: Any] = [
            MessageDAO.UserInfoKey.conversationId: message.conversationId,
            MessageDAO.UserInfoKey.message: message,
            MessageDAO.UserInfoKey.messsageSource: messageSource,
            MessageDAO.UserInfoKey.silentNotification: silentNotification
        ]
        Queue.main.autoSync {
            NotificationCenter.default.post(name: MessageDAO.didRedecryptMessageNotification, object: self, userInfo: userInfo)
        }
    }
        
    public func updateMessageContentAndStatus(content: String, status: String, mention: MessageMention?, messageId: String, category: String, conversationId: String, messageSource: String, silentNotification: Bool) {
        let assignments = [
            Message.column(of: .content).set(to: content),
            Message.column(of: .status).set(to: status)
        ]
        updateRedecryptMessage(assignments: assignments,
                               mention: mention,
                               messageId: messageId,
                               category: category,
                               conversationId: conversationId,
                               messageSource: messageSource,
                               silentNotification: silentNotification)
    }
    
    public func updateMediaMessage(mediaData: TransferAttachmentData, status: String, messageId: String, category: String, conversationId: String, mediaStatus: MediaStatus, messageSource: String, silentNotification: Bool) {
        let assignments = [
            Message.column(of: .content).set(to: mediaData.attachmentId),
            Message.column(of: .mediaMimeType).set(to: mediaData.mimeType),
            Message.column(of: .mediaSize).set(to: mediaData.size),
            Message.column(of: .mediaDuration).set(to: mediaData.duration),
            Message.column(of: .mediaWidth).set(to: mediaData.width),
            Message.column(of: .mediaHeight).set(to: mediaData.height),
            Message.column(of: .thumbImage).set(to: mediaData.thumbnail),
            Message.column(of: .mediaKey).set(to: mediaData.key),
            Message.column(of: .mediaDigest).set(to: mediaData.digest),
            Message.column(of: .mediaStatus).set(to: mediaStatus.rawValue),
            Message.column(of: .mediaWaveform).set(to: mediaData.waveform),
            Message.column(of: .name).set(to: mediaData.name),
            Message.column(of: .status).set(to: status)
        ]
        updateRedecryptMessage(assignments: assignments,
                               messageId: messageId,
                               category: category,
                               conversationId: conversationId,
                               messageSource: messageSource,
                               silentNotification: silentNotification)
    }
    
    public func updateLiveMessage(liveData: TransferLiveData, content: String?, status: String, messageId: String, category: String, conversationId: String, messageSource: String, silentNotification: Bool) {
        let assignments = [
            Message.column(of: .content).set(to: content),
            Message.column(of: .mediaWidth).set(to: liveData.width),
            Message.column(of: .mediaHeight).set(to: liveData.height),
            Message.column(of: .mediaUrl).set(to: liveData.url),
            Message.column(of: .thumbUrl).set(to: liveData.thumbUrl),
            Message.column(of: .status).set(to: status)
        ]
        updateRedecryptMessage(assignments: assignments,
                               messageId: messageId,
                               category: category,
                               conversationId: conversationId,
                               messageSource: messageSource,
                               silentNotification: silentNotification)
    }
    
    public func updateStickerMessage(stickerData: TransferStickerData, status: String, messageId: String, category: String, conversationId: String, messageSource: String, silentNotification: Bool) {
        let assignments = [
            Message.column(of: .stickerId).set(to: stickerData.stickerId),
            Message.column(of: .status).set(to: status),
        ]
        updateRedecryptMessage(assignments: assignments,
                               messageId: messageId,
                               category: category,
                               conversationId: conversationId,
                               messageSource: messageSource,
                               silentNotification: silentNotification)
    }
    
    public func updateContactMessage(transferData: TransferContactData, status: String, messageId: String, category: String, conversationId: String, messageSource: String, silentNotification: Bool) {
        let assignments = [
            Message.column(of: .sharedUserId).set(to: transferData.userId),
            Message.column(of: .status).set(to: status)
        ]
        updateRedecryptMessage(assignments: assignments,
                               messageId: messageId,
                               category: category,
                               conversationId: conversationId,
                               messageSource: messageSource,
                               silentNotification: silentNotification)
    }
    
    public func updateTranscriptMessage(children: [TranscriptMessage], status: String, mediaStatus: MediaStatus, content: String, messageId: String, category: String, conversationId: String, messageSource: String, silentNotification: Bool) {
        let assignments = [
            Message.column(of: .status).set(to: status),
            Message.column(of: .content).set(to: content),
            Message.column(of: .mediaStatus).set(to: mediaStatus.rawValue)
        ]
        updateRedecryptMessage(assignments: assignments,
                               messageId: messageId,
                               category: category,
                               conversationId: conversationId,
                               messageSource: messageSource,
                               children: children,
                               silentNotification: silentNotification)
    }
    
    public func messages(limit: Int, after messageId: String?) -> [Message] {
        var sql = "SELECT * FROM messages"
        if let messageId {
            sql += " WHERE ROWID > IFNULL((SELECT ROWID FROM messages WHERE id = '\(messageId)'), 0)"
        }
        sql += " ORDER BY ROWID LIMIT ?"
        return db.select(with: sql, arguments: [limit])
    }
    
    public func messagesCount() -> Int {
        let count: Int? = db.select(with: "SELECT COUNT(*) FROM messages")
        return count ?? 0
    }
    
    public func lastMessageCreatedAt() -> String? {
        db.select(column: Message.column(of: .createdAt),
                  from: Message.self,
                  order: [Message.column(of: .createdAt).desc])
    }
    
    public func save(message: Message) {
        db.write { db in
            let exists = try message.exists(db)
            guard !exists else {
                return
            }
            try message.save(db)
            let shouldInsertIntoFTSTable = AppGroupUserDefaults.Database.isFTSInitialized
                && message.status != MessageStatus.FAILED.rawValue
                && MessageCategory.ftsAvailableCategoryStrings.contains(message.category)
            if shouldInsertIntoFTSTable {
                let children: [TranscriptMessage]?
                if message.category.hasSuffix("_TRANSCRIPT") {
                    children = try TranscriptMessage
                        .filter(TranscriptMessage.column(of: .transcriptId) == message.messageId)
                        .fetchAll(db)
                } else {
                    children = nil
                }
                try insertFTSContent(db, message: message, children: children)
            }
        }
    }
    
    public func messageContent(conversationId: String, messageId: String) -> String? {
        db.select(column: Message.column(of: .content),
                  from: Message.self,
                  where: Message.column(of: .conversationId) == conversationId && Message.column(of: .messageId) == messageId)
    }
    
    private func clearPinMessageContent(quoteMessageIds: [String], conversationId: String, from database: GRDB.Database) throws {
        let ids: [String] = try quoteMessageIds.flatMap { (quoteMessageId) -> [String] in
            let condition: SQLSpecificExpressible = Message.column(of: .conversationId) == conversationId
                && Message.column(of: .quoteMessageId) == quoteMessageId
                && Message.column(of: .category) == MessageCategory.MESSAGE_PIN.rawValue
            let pinMessageIds: [String] = try Message
                .select(Message.column(of: .messageId))
                .filter(condition)
                .fetchAll(database)
            for id in pinMessageIds {
                try Message
                    .filter(Message.column(of: .messageId) == id)
                    .updateAll(database, [Message.column(of: .content).set(to: nil)])
            }
            return pinMessageIds
        }
        database.afterNextTransaction { db in
            for id in ids {
                let updateChange = ConversationChange(conversationId: conversationId, action: .updateMessage(messageId: id))
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: updateChange)
            }
        }
    }
    
}

extension MessageDAO {
    
    private func insertFTSContent(_ db: GRDB.Database, message: Message, children: [TranscriptMessage]?) throws {
        let shouldInsertIntoFTSTable = AppGroupUserDefaults.Database.isFTSInitialized
            && message.status != MessageStatus.FAILED.rawValue
            && MessageCategory.ftsAvailableCategoryStrings.contains(message.category)
        if shouldInsertIntoFTSTable {
            let content = ftsContent(messageId: message.messageId,
                                     category: message.category,
                                     content: message.content,
                                     name: message.name,
                                     children: children)
            let arguments = StatementArguments([
                uuidTokenString(uuidString: message.conversationId),
                uuidTokenString(uuidString: message.userId),
                uuidTokenString(uuidString: message.messageId),
                content,
                unixTimeInMilliseconds(iso8601: message.createdAt),
                nil,
                nil
            ])
            try db.execute(sql: "INSERT INTO \(Message.ftsTableName) VALUES (?, ?, ?, ?, ?, ?, ?)", arguments: arguments)
        }
    }
    
    private func deleteFTSContent(_ db: GRDB.Database, messageId: String) throws {
        let sql = "DELETE FROM \(Message.ftsTableName) WHERE id MATCH ?"
        try db.execute(sql: sql, arguments: [uuidTokenString(uuidString: messageId)])
    }
    
}
