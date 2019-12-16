import UserNotifications
import WCDBSwift
import UIKit

final class MessageDAO {

    static let shared = MessageDAO()

    static let sqlTriggerLastMessageInsert = """
    CREATE TRIGGER IF NOT EXISTS conversation_last_message_update AFTER INSERT ON messages
    BEGIN
        UPDATE conversations SET last_message_id = new.id, last_message_created_at = new.created_at WHERE conversation_id = new.conversation_id;
    END
    """
    static let sqlTriggerLastMessageDelete = """
    CREATE TRIGGER IF NOT EXISTS conversation_last_message_delete AFTER DELETE ON messages
    BEGIN
        UPDATE conversations SET last_message_id = (select id from messages where conversation_id = old.conversation_id order by created_at DESC limit 1) WHERE conversation_id = old.conversation_id;
    END
    """
    static let sqlTriggerUnseenMessageInsert = """
    CREATE TRIGGER IF NOT EXISTS conversation_unseen_message_count_insert AFTER INSERT ON messages
    BEGIN
        UPDATE conversations SET unseen_message_count = (SELECT count(m.id) FROM messages m, users u WHERE m.user_id = u.user_id AND u.relationship != 'ME' AND m.status = 'DELIVERED' AND conversation_id = new.conversation_id) where conversation_id = new.conversation_id;
    END
    """
    static let sqlQueryLastUnreadMessageTime = """
        SELECT created_at FROM messages
        WHERE conversation_id = ? AND status = 'DELIVERED' AND user_id != ?
        ORDER BY created_at DESC
        LIMIT 1
    """
    static let sqlQueryFullMessage = """
    SELECT m.id, m.conversation_id, m.user_id, m.category, m.content, m.media_url, m.media_mime_type,
        m.media_size, m.media_duration, m.media_width, m.media_height, m.media_hash, m.media_key,
        m.media_digest, m.media_status, m.media_waveform, m.media_local_id, m.thumb_image, m.thumb_url, m.status, m.participant_id, m.snapshot_id, m.name,
        m.sticker_id, m.created_at, u.full_name as userFullName, u.identity_number as userIdentityNumber, u.avatar_url as userAvatarUrl, u.app_id as appId,
               u1.full_name as participantFullName, u1.user_id as participantUserId,
               s.amount as snapshotAmount, s.asset_id as snapshotAssetId, s.type as snapshotType, a.symbol as assetSymbol, a.icon_url as assetIcon,
               st.asset_width as assetWidth, st.asset_height as assetHeight, st.asset_url as assetUrl, alb.category as assetCategory,
               m.action as actionName, m.shared_user_id as sharedUserId, su.full_name as sharedUserFullName, su.identity_number as sharedUserIdentityNumber, su.avatar_url as sharedUserAvatarUrl, su.app_id as sharedUserAppId, su.is_verified as sharedUserIsVerified, m.quote_message_id, m.quote_content
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
    static let sqlQueryFullMessageBeforeRowId = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ? AND m.ROWID < ?
    ORDER BY m.created_at DESC
    LIMIT ?
    """
    static let sqlQueryFullMessageAfterRowId = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ? AND m.ROWID > ?
    ORDER BY m.created_at ASC
    LIMIT ?
    """
    static let sqlQueryFullAudioMessages = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ? AND m.category in ('SIGNAL_AUDIO', 'PLAIN_AUDIO')
    """
    static let sqlQueryFullDataMessages = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ? AND m.category in ('SIGNAL_DATA', 'PLAIN_DATA')
    """
    static let sqlQueryFullMessageById = sqlQueryFullMessage + " WHERE m.id = ?"
    private static let sqlQueryPendingMessages = """
    SELECT m.id, m.conversation_id, m.user_id, m.category, m.content, m.media_url, m.media_mime_type,
        m.media_size, m.media_duration, m.media_width, m.media_height, m.media_hash, m.media_key,
        m.media_digest, m.media_status, m.media_waveform, m.media_local_id, m.thumb_image, m.thumb_url, m.status, m.participant_id, m.snapshot_id, m.name,
        m.sticker_id, m.created_at FROM messages m
    INNER JOIN conversations c ON c.conversation_id = m.conversation_id AND c.status = 1
    WHERE m.user_id = ? AND m.status = 'SENDING' AND m.media_status = 'PENDING'
    ORDER BY m.created_at ASC
    """
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
    static let sqlSearchMessageContent = """
    SELECT m.id, m.category, m.content, m.created_at, u.user_id, u.full_name, u.avatar_url, u.is_verified, u.app_id
        FROM messages m
        LEFT JOIN users u ON m.user_id = u.user_id
        WHERE conversation_id = ? AND m.category in ('SIGNAL_TEXT', 'SIGNAL_DATA','PLAIN_TEXT','PLAIN_DATA')
        AND m.status != 'FAILED' AND (m.content LIKE ? ESCAPE '/' OR m.name LIKE ? ESCAPE '/')
    """
    
    static let sqlQueryGalleryItem = """
    SELECT m.conversation_id, m.id, m.category, m.media_url, m.media_mime_type, m.media_width,
           m.media_height, m.media_status, m.media_duration, m.thumb_image, m.thumb_url, m.created_at
    FROM messages m
    WHERE conversation_id = ?
        AND ((category LIKE '%_IMAGE' OR category LIKE '%_VIDEO') AND status != 'FAILED' AND (NOT (user_id = ? AND media_status != 'DONE'))
             OR category LIKE '%_LIVE')
    """
    func getMediaUrls(likeCategory category: String) -> [String] {
        return MixinDatabase.shared.getStringValues(column: Message.Properties.mediaUrl.asColumnResult(),
                                                    tableName: Message.tableName,
                                                    condition: Message.Properties.category.like("%\(category)"))
    }

    func deleteMessages(conversationId: String, category: String) {
        MixinDatabase.shared.delete(table: Message.tableName, condition: Message.Properties.conversationId == conversationId && Message.Properties.category.like("%\(category)"))
    }

    func findFailedMessages(conversationId: String, userId: String) -> [String] {
        return MixinDatabase.shared.getStringValues(column: Message.Properties.messageId.asColumnResult(), tableName: Message.tableName, condition: Message.Properties.conversationId == conversationId && Message.Properties.userId == userId && Message.Properties.status == MessageStatus.FAILED.rawValue, orderBy: [Message.Properties.createdAt.asOrder(by: .descending)], limit: 1000)
    }

    func clearChat(conversationId: String, autoNotification: Bool = true) {
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: Message.tableName,
                          where: Message.Properties.conversationId == conversationId)
            try db.update(table: Conversation.tableName,
                          on: [Conversation.Properties.unseenMessageCount],
                          with: [0],
                          where: Conversation.Properties.conversationId == conversationId)
        }
        if autoNotification {
            let change = ConversationChange(conversationId: conversationId, action: .reload)
            NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
        }
    }

    func updateMessageContentAndMediaStatus(content: String, mediaStatus: MediaStatus, messageId: String, conversationId: String) {
        guard MixinDatabase.shared.update(maps: [(Message.Properties.content, content), (Message.Properties.mediaStatus, mediaStatus.rawValue)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId && Message.Properties.category != MessageCategory.MESSAGE_RECALL.rawValue) else {
            return
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateMediaStatus(messageId: messageId, mediaStatus: mediaStatus))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }

    func updateMessageQuoteContent(conversationId: String, quoteMessageId: String, quoteContent: Data) {
        MixinDatabase.shared.update(maps: [(Message.Properties.quoteContent, quoteContent)], tableName: Message.tableName, condition: Message.Properties.conversationId == conversationId && Message.Properties.quoteMessageId == quoteContent)
    }

    func isExist(messageId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Message.self, condition: Message.Properties.messageId == messageId)
    }

    @discardableResult
    func updateMessageStatus(messageId: String, status: String, from: String, updateUnseen: Bool = false) -> Bool {
        guard let oldMessage: Message = MixinDatabase.shared.getCodable(condition: Message.Properties.messageId == messageId) else {
            return false
        }

        guard oldMessage.status != MessageStatus.FAILED.rawValue else {
            let error = MixinServicesError.badMessageData(id: messageId, status: status, from: from)
            Reporter.report(error: error)
            return false
        }

        guard MessageStatus.getOrder(messageStatus: status) > MessageStatus.getOrder(messageStatus: oldMessage.status) else {
            return false
        }

        let conversationId = oldMessage.conversationId
        if updateUnseen {
            MixinDatabase.shared.transaction { (database) in
                try database.update(table: Message.tableName, on: [Message.Properties.status], with: [status], where: Message.Properties.messageId == messageId)
                try updateUnseenMessageCount(database: database, conversationId: conversationId)
            }
        } else {
            MixinDatabase.shared.update(maps: [(Message.Properties.status, status)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId)
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateMessageStatus(messageId: messageId, newStatus: MessageStatus(rawValue: status) ?? .UNKNOWN))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
        return true
    }

    func updateUnseenMessageCount(database: Database, conversationId: String) throws {
        try database.prepareUpdateSQL(sql: "UPDATE conversations SET unseen_message_count = (SELECT count(m.id) FROM messages m, users u WHERE m.user_id = u.user_id AND u.relationship != 'ME' AND m.status = 'DELIVERED' AND conversation_id = ?) where conversation_id = ?").execute(with: [conversationId, conversationId])
    }

    @discardableResult
    func updateMediaMessage(messageId: String, keyValues: [(PropertyConvertible, ColumnEncodable?)]) -> Bool {
        return MixinDatabase.shared.update(maps: keyValues, tableName: Message.tableName, condition: Message.Properties.messageId == messageId && Message.Properties.category != MessageCategory.MESSAGE_RECALL.rawValue)
    }

    func updateMediaMessage(messageId: String, mediaUrl: String, status: MediaStatus, conversationId: String) {
        guard MixinDatabase.shared.update(maps: [(Message.Properties.mediaUrl, mediaUrl), (Message.Properties.mediaStatus, status.rawValue)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId && Message.Properties.category != MessageCategory.MESSAGE_RECALL.rawValue) else {
            return
        }

        let change = ConversationChange(conversationId: conversationId, action: .updateMessage(messageId: messageId))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }

    func updateMediaStatus(messageId: String, status: MediaStatus, conversationId: String) {
        guard MixinDatabase.shared.update(maps: [(Message.Properties.mediaStatus, status.rawValue)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId && Message.Properties.category != MessageCategory.MESSAGE_RECALL.rawValue) else {
            return
        }
        
        let change = ConversationChange(conversationId: conversationId, action: .updateMediaStatus(messageId: messageId, mediaStatus: status))
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: change)
    }

    func updateOldStickerMessages() {
        MixinDatabase.shared.transaction { (database) in
            guard try database.isColumnExist(tableName: Message.tableName, columnName: "album_id") else {
                return
            }
            try database.prepareUpdateSQL(sql: MessageDAO.sqlUpdateOldStickers).execute()
        }
    }

    func getFullMessage(messageId: String) -> MessageItem? {
        return MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryFullMessageById, values: [messageId]).first
    }

    func getMessage(messageId: String) -> Message? {
        return MixinDatabase.shared.getCodable(condition: Message.Properties.messageId == messageId)
    }

    func getPendingMessages() -> [Message] {
        return MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryPendingMessages, values: [AccountAPI.shared.accountUserId])
    }
    
    func firstUnreadMessage(conversationId: String) -> Message? {
        guard hasUnreadMessage(conversationId: conversationId) else {
            return nil
        }
        let myLastMessage: Message? = MixinDatabase.shared.getCodable(condition: Message.Properties.conversationId == conversationId && Message.Properties.userId == AccountAPI.shared.accountUserId,
                                                                      orderBy: [Message.Properties.createdAt.asOrder(by: .descending)])
        let lastReadCondition: Condition
        if let myLastMessage = myLastMessage {
            lastReadCondition = Message.Properties.conversationId == conversationId
                && Message.Properties.category != MessageCategory.SYSTEM_CONVERSATION.rawValue
                && Message.Properties.status == MessageStatus.READ.rawValue
                && Message.Properties.userId != AccountAPI.shared.accountUserId
                && Message.Properties.createdAt > myLastMessage.createdAt
        } else {
            lastReadCondition = Message.Properties.conversationId == conversationId
                && Message.Properties.category != MessageCategory.SYSTEM_CONVERSATION.rawValue
                && Message.Properties.status == MessageStatus.READ.rawValue
                && Message.Properties.userId != AccountAPI.shared.accountUserId
        }
        let lastReadMessage: Message? = MixinDatabase.shared.getCodable(condition: lastReadCondition,
                                                                        orderBy: [Message.Properties.createdAt.asOrder(by: .descending)])
        let firstUnreadCondition: Condition
        if let lastReadMessage = lastReadMessage {
            firstUnreadCondition = Message.Properties.conversationId == conversationId
                && Message.Properties.status == MessageStatus.DELIVERED.rawValue
                && Message.Properties.userId != AccountAPI.shared.accountUserId
                && Message.Properties.createdAt > lastReadMessage.createdAt
        } else if let myLastMessage = myLastMessage {
            firstUnreadCondition = Message.Properties.conversationId == conversationId
                && Message.Properties.status == MessageStatus.DELIVERED.rawValue
                && Message.Properties.userId != AccountAPI.shared.accountUserId
                && Message.Properties.createdAt > myLastMessage.createdAt
        } else {
            firstUnreadCondition = Message.Properties.conversationId == conversationId
                && Message.Properties.status == MessageStatus.DELIVERED.rawValue
                && Message.Properties.userId != AccountAPI.shared.accountUserId
        }
        return MixinDatabase.shared.getCodable(condition: firstUnreadCondition,
                                               orderBy: [Message.Properties.createdAt.asOrder(by: .ascending)])
    }
    
    typealias MessagesResult = (messages: [MessageItem], didReachBegin: Bool, didReachEnd: Bool)
    func getMessages(conversationId: String, aroundMessageId messageId: String, count: Int) -> MessagesResult? {
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
    
    func getMessages(conversationId: String, aboveMessage location: MessageItem, count: Int) -> [MessageItem] {
        let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                  condition: Message.Properties.messageId == location.messageId)
        let messages: [MessageItem] = MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryFullMessageBeforeRowId,
                                                                       values: [conversationId, rowId, count])
        return messages.reversed()
    }
    
    func getMessages(conversationId: String, belowMessage location: MessageItem, count: Int) -> [MessageItem] {
        let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                  condition: Message.Properties.messageId == location.messageId)
        let messages: [MessageItem] = MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryFullMessageAfterRowId,
                                                                       values: [conversationId, rowId, count])
        return messages
    }
    
    func getDataMessages(conversationId: String, earlierThan location: MessageItem?, count: Int) -> [MessageItem] {
        var sql = MessageDAO.sqlQueryFullDataMessages
        if let location = location {
            let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                      condition: Message.Properties.messageId == location.messageId)
            sql += " AND m.ROWID < \(rowId)"
        }
        sql += " ORDER BY m.created_at DESC LIMIT ?"
        let messages: [MessageItem] = MixinDatabase.shared.getCodables(sql: sql, values: [conversationId, count])
        return messages
    }
    
    func getAudioMessages(conversationId: String, earlierThan location: MessageItem?, count: Int) -> [MessageItem] {
        var sql = MessageDAO.sqlQueryFullAudioMessages
        if let location = location {
            let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                      condition: Message.Properties.messageId == location.messageId)
            sql += " AND m.ROWID < \(rowId)"
        }
        sql += " ORDER BY m.created_at DESC LIMIT ?"
        let messages: [MessageItem] = MixinDatabase.shared.getCodables(sql: sql, values: [conversationId, count])
        return messages
    }
    
    func getFirstNMessages(conversationId: String, count: Int) -> [MessageItem] {
        return MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryFirstNMessages, values: [conversationId, count])
    }
    
    func getLastNMessages(conversationId: String, count: Int) -> [MessageItem] {
        let messages: [MessageItem] =  MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryLastNMessages, values: [conversationId, count])
        return messages.reversed()
    }
    
    func getMessages(conversationId: String, contentLike keyword: String, belowMessageId location: String?, limit: Int?) -> [MessageSearchResult] {
        var results = [MessageSearchResult]()
        
        var sql: String!
        if let location = location {
            let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                      condition: Message.Properties.messageId == location)
            sql = MessageDAO.sqlSearchMessageContent + " AND m.ROWID < \(rowId)"
        } else {
            sql = MessageDAO.sqlSearchMessageContent
        }
        if let limit = limit {
            sql += " ORDER BY m.created_at DESC LIMIT \(limit)"
        } else {
            sql += " ORDER BY m.created_at DESC"
        }
        
        do {
            let stmt = StatementSelectSQL(sql: sql)
            let cs = try MixinDatabase.shared.database.prepare(stmt)
            
            let bindingCounter = Counter(value: 0)
            let wildcardedKeyword = "%\(keyword.sqlEscaped)%"
            cs.bind(conversationId, toIndex: bindingCounter.advancedValue)
            cs.bind(wildcardedKeyword, toIndex: bindingCounter.advancedValue)
            cs.bind(wildcardedKeyword, toIndex: bindingCounter.advancedValue)
            
            while try cs.step() {
                let counter = Counter(value: -1)
                let result = MessageSearchResult(conversationId: conversationId,
                                                 messageId: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 category: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 content: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 createdAt: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 userId: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 fullname: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 avatarUrl: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 isVerified: cs.value(atIndex: counter.advancedValue) ?? false,
                                                 appId: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 keyword: keyword)
                results.append(result)
            }
        } catch {
            UIApplication.traceError(error)
        }
        
        return results
    }
    
    func getInvitationMessage(conversationId: String, inviteeUserId: String) -> Message? {
        let condition: Condition = Message.Properties.conversationId == conversationId
            && Message.Properties.category == MessageCategory.SYSTEM_CONVERSATION.rawValue
            && Message.Properties.action == SystemConversationAction.ADD.rawValue
            && Message.Properties.participantId == inviteeUserId
        let order = [Message.Properties.createdAt.asOrder(by: .ascending)]
        return MixinDatabase.shared.getCodable(condition: condition, orderBy: order)
    }
    
    func getUnreadMessagesCount(conversationId: String) -> Int {
        guard let firstUnreadMessage = self.firstUnreadMessage(conversationId: conversationId) else {
            return 0
        }
        return MixinDatabase.shared.getCount(on: Message.Properties.messageId.count(),
                                             fromTable: Message.tableName,
                                             condition: Message.Properties.conversationId == conversationId && Message.Properties.createdAt >= firstUnreadMessage.createdAt)
    }
    
    func getGalleryItems(conversationId: String, location: GalleryItem?, count: Int) -> [GalleryItem] {
        assert(count != 0)
        var items = [GalleryItem]()
        var sql = MessageDAO.sqlQueryGalleryItem
        if let location = location {
            let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                      condition: Message.Properties.messageId == location.messageId)
            if count > 0 {
                sql += " AND ROWID > \(rowId) ORDER BY created_at ASC LIMIT \(count)"
            } else {
                sql += " AND ROWID < \(rowId) ORDER BY created_at DESC LIMIT \(-count)"
            }
        } else {
            assert(count > 0)
            sql += " ORDER BY created_at DESC LIMIT \(count)"
        }
        
        do {
            let stmt = StatementSelectSQL(sql: sql)
            let cs = try MixinDatabase.shared.database.prepare(stmt)
            
            let bindingCounter = Counter(value: 0)
            cs.bind(conversationId, toIndex: bindingCounter.advancedValue)
            cs.bind(AccountAPI.shared.accountUserId, toIndex: bindingCounter.advancedValue)
            
            while try cs.step() {
                let counter = Counter(value: -1)
                let item = GalleryItem(conversationId: cs.value(atIndex: counter.advancedValue) ?? "",
                                       messageId: cs.value(atIndex: counter.advancedValue) ?? "",
                                       category: cs.value(atIndex: counter.advancedValue) ?? "",
                                       mediaUrl: cs.value(atIndex: counter.advancedValue),
                                       mediaMimeType: cs.value(atIndex: counter.advancedValue),
                                       mediaWidth: cs.value(atIndex: counter.advancedValue),
                                       mediaHeight: cs.value(atIndex: counter.advancedValue),
                                       mediaStatus: cs.value(atIndex: counter.advancedValue),
                                       mediaDuration: cs.value(atIndex: counter.advancedValue),
                                       thumbImage: cs.value(atIndex: counter.advancedValue),
                                       thumbUrl: cs.value(atIndex: counter.advancedValue),
                                       createdAt: cs.value(atIndex: counter.advancedValue) ?? "")
                if let item = item {
                    items.append(item)
                }
            }
        } catch {
            UIApplication.traceError(error)
        }
        
        if count > 0 {
            return items
        } else {
            return items.reversed()
        }
    }
    
    func insertMessage(message: Message, messageSource: String) {
        var message = message
        if let quoteMessageId = message.quoteMessageId, let quoteContent = getQuoteMessage(messageId: quoteMessageId) {
            message.quoteContent = quoteContent
        }
        MixinDatabase.shared.transaction { (db) in
            try insertMessage(database: db, message: message, messageSource: messageSource)
        }
    }

    func insertMessage(database: Database, message: Message, messageSource: String) throws {
        if message.category.hasPrefix("SIGNAL_") {
            try database.insert(objects: message, intoTable: Message.tableName)
        } else {
            try database.insertOrReplace(objects: message, intoTable: Message.tableName)
        }

        guard let newMessage: MessageItem = try database.prepareSelectSQL(on: MessageItem.Properties.all, sql: MessageDAO.sqlQueryFullMessageById, values: [message.messageId]).allObjects().first else {
            return
        }
        let change = ConversationChange(conversationId: newMessage.conversationId, action: .addMessage(message: newMessage))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)

        if messageSource != BlazeMessageAction.listPendingMessages.rawValue || abs(message.createdAt.toUTCDate().timeIntervalSince1970 - Date().timeIntervalSince1970) < 60 {
            ConcurrentJobQueue.shared.sendNotifaction(message: newMessage)
        }
    }

    func recallMessage(message: Message) {
        let messageId = message.messageId
        ReceiveMessageService.shared.stopRecallMessage(messageId: messageId, category: message.category, conversationId: message.conversationId, mediaUrl: message.mediaUrl)

        let quoteMessageIds = MixinDatabase.shared.getStringValues(column: Message.Properties.messageId.asColumnResult(), tableName: Message.tableName, condition: Message.Properties.conversationId == message.conversationId &&  Message.Properties.quoteMessageId == messageId)
        MixinDatabase.shared.transaction { (database) in
            try MessageDAO.shared.recallMessage(database: database, messageId: message.messageId, conversationId: message.conversationId, category: message.category, status: message.status, quoteMessageIds: quoteMessageIds)
        }
    }

    func recallMessage(database: Database, messageId: String, conversationId: String, category: String, status: String, quoteMessageIds: [String]) throws {
        var values: [(PropertyConvertible, ColumnEncodable?)] = [
            (Message.Properties.category, MessageCategory.MESSAGE_RECALL.rawValue)
        ]

        if category.hasSuffix("_TEXT") {
            values.append((Message.Properties.content, MixinDatabase.NullValue()))
            values.append((Message.Properties.quoteMessageId, MixinDatabase.NullValue()))
            values.append((Message.Properties.quoteContent, MixinDatabase.NullValue()))
        } else if category.hasSuffix("_IMAGE") ||
            category.hasSuffix("_VIDEO") ||
            category.hasSuffix("_LIVE") ||
            category.hasSuffix("_DATA") ||
            category.hasSuffix("_AUDIO") {
            values.append((Message.Properties.content, MixinDatabase.NullValue()))
            values.append((Message.Properties.mediaUrl, MixinDatabase.NullValue()))
            values.append((Message.Properties.mediaStatus, MixinDatabase.NullValue()))
            values.append((Message.Properties.mediaMimeType, MixinDatabase.NullValue()))
            values.append((Message.Properties.mediaSize, 0))
            values.append((Message.Properties.mediaDuration, 0))
            values.append((Message.Properties.mediaWidth, 0))
            values.append((Message.Properties.mediaHeight, 0))
            values.append((Message.Properties.thumbImage, MixinDatabase.NullValue()))
            values.append((Message.Properties.thumbUrl, MixinDatabase.NullValue()))
            values.append((Message.Properties.mediaKey, MixinDatabase.NullValue()))
            values.append((Message.Properties.mediaDigest, MixinDatabase.NullValue()))
            values.append((Message.Properties.mediaWaveform, MixinDatabase.NullValue()))
            values.append((Message.Properties.name, MixinDatabase.NullValue()))
        } else if category.hasSuffix("_STICKER") {
            values.append((Message.Properties.stickerId, MixinDatabase.NullValue()))
        } else if category.hasSuffix("_CONTACT") {
            values.append((Message.Properties.sharedUserId, MixinDatabase.NullValue()))
        }
        if status == MessageStatus.FAILED.rawValue {
            values.append((Message.Properties.status, MessageStatus.DELIVERED.rawValue))
        }

        try database.update(maps: values, tableName: Message.tableName, condition: Message.Properties.messageId == messageId)

        if status == MessageStatus.FAILED.rawValue {
            try MessageDAO.shared.updateUnseenMessageCount(database: database, conversationId: conversationId)
        }

        if quoteMessageIds.count > 0, let quoteMessage: MessageItem = try database.prepareSelectSQL(on: MessageItem.Properties.all, sql: MessageDAO.sqlQueryQuoteMessageById, values: [messageId]).allObjects().first, let data = try? JSONEncoder().encode(quoteMessage) {
            try database.update(maps: [(Message.Properties.quoteContent, data)], tableName: Message.tableName, condition: Message.Properties.messageId.in(quoteMessageIds))
        }

        let messageIds = quoteMessageIds + [messageId]
        for messageId in messageIds {
            let change = ConversationChange(conversationId: conversationId, action: .recallMessage(messageId: messageId))
            NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
        }
    }
    
    @discardableResult
    func deleteMessage(id: String) -> Bool {
        var deleteCount = 0
        MixinDatabase.shared.transaction { (db) in
            let delete = try db.prepareDelete(fromTable: Message.tableName).where(Message.Properties.messageId == id)
            try delete.execute()
            deleteCount = delete.changes ?? 0
        }
        return deleteCount > 0
    }
    
    func hasSentMessage(inConversationOf conversationId: String) -> Bool {
        let myId = AccountAPI.shared.accountUserId
        return MixinDatabase.shared.isExist(type: Message.self, condition: Message.Properties.conversationId == conversationId && Message.Properties.userId == myId)
    }
    
    func hasUnreadMessage(conversationId: String) -> Bool {
        let condition: Condition = Message.Properties.conversationId == conversationId
            && Message.Properties.status == MessageStatus.DELIVERED.rawValue
            && Message.Properties.userId != AccountAPI.shared.accountUserId
        return MixinDatabase.shared.isExist(type: Message.self, condition: condition)
    }
    
    func hasMessage(id: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Message.self, condition: Message.Properties.messageId == id)
    }

    func getQuoteMessage(messageId: String?) -> Data? {
        guard let quoteMessageId = messageId, let quoteMessage: MessageItem = MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryQuoteMessageById, values: [quoteMessageId]).first else {
            return nil
        }
        return try? JSONEncoder().encode(quoteMessage)
    }

}

extension MessageDAO {

    private func updateRedecryptMessage(keys: [PropertyConvertible], values: [ColumnEncodable?], messageId: String, category: String, conversationId: String, messageSource: String) {
        var newMessage: MessageItem?
        MixinDatabase.shared.transaction { (database) in
            let updateStatment = try database.prepareUpdate(table: Message.tableName, on: keys).where(Message.Properties.messageId == messageId && Message.Properties.category != MessageCategory.MESSAGE_RECALL.rawValue)
            try updateStatment.execute(with: values)
            guard updateStatment.changes ?? 0 > 0 else {
                return
            }

            try MessageDAO.shared.updateUnseenMessageCount(database: database, conversationId: conversationId)

            newMessage = try database.prepareSelectSQL(on: MessageItem.Properties.all, sql: MessageDAO.sqlQueryFullMessageById, values: [messageId]).allObjects().first
        }

        guard let message = newMessage else {
            return
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateMessage(messageId: messageId))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
        
        if messageSource != BlazeMessageAction.listPendingMessages.rawValue || abs(message.createdAt.toUTCDate().timeIntervalSince1970 - Date().timeIntervalSince1970) < 60 {
            ConcurrentJobQueue.shared.sendNotifaction(message: message)
        }
    }

    func updateMessageContentAndStatus(content: String, status: String, messageId: String, category: String, conversationId: String, messageSource: String) {
        updateRedecryptMessage(keys: [Message.Properties.content, Message.Properties.status], values: [content, status], messageId: messageId, category: category, conversationId: conversationId, messageSource: messageSource)
    }

    func updateMediaMessage(mediaData: TransferAttachmentData, status: String, messageId: String, category: String, conversationId: String, mediaStatus: MediaStatus, messageSource: String) {
        updateRedecryptMessage(keys: [
            Message.Properties.content,
            Message.Properties.mediaMimeType,
            Message.Properties.mediaSize,
            Message.Properties.mediaDuration,
            Message.Properties.mediaWidth,
            Message.Properties.mediaHeight,
            Message.Properties.thumbImage,
            Message.Properties.mediaKey,
            Message.Properties.mediaDigest,
            Message.Properties.mediaStatus,
            Message.Properties.mediaWaveform,
            Message.Properties.name,
            Message.Properties.status
        ], values: [
            mediaData.attachmentId,
            mediaData.mimeType,
            mediaData.size,
            mediaData.duration,
            mediaData.width,
            mediaData.height,
            mediaData.thumbnail,
            mediaData.key,
            mediaData.digest,
            mediaStatus.rawValue,
            mediaData.waveform,
            mediaData.name,
            status
            ], messageId: messageId, category: category, conversationId: conversationId, messageSource: messageSource)
    }
    
    func updateLiveMessage(liveData: TransferLiveData, status: String, messageId: String, category: String, conversationId: String, messageSource: String) {
        let keys = [
            Message.Properties.mediaWidth,
            Message.Properties.mediaHeight,
            Message.Properties.mediaUrl,
            Message.Properties.thumbUrl,
            Message.Properties.status
        ]
        let values: [ColumnEncodable] = [
            liveData.width,
            liveData.height,
            liveData.url,
            liveData.thumbUrl,
            status
        ]
        updateRedecryptMessage(keys: keys, values: values, messageId: messageId, category: category, conversationId: conversationId, messageSource: messageSource)
    }
    
    func updateStickerMessage(stickerData: TransferStickerData, status: String, messageId: String, category: String, conversationId: String, messageSource: String) {
        updateRedecryptMessage(keys: [Message.Properties.stickerId, Message.Properties.status], values: [stickerData.stickerId, status], messageId: messageId, category: category, conversationId: conversationId, messageSource: messageSource)
    }

    func updateContactMessage(transferData: TransferContactData, status: String, messageId: String, category: String, conversationId: String, messageSource: String) {
        updateRedecryptMessage(keys: [Message.Properties.sharedUserId, Message.Properties.status], values: [transferData.userId, status], messageId: messageId, category: category, conversationId: conversationId, messageSource: messageSource)
    }

}
