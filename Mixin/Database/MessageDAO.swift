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
    static let sqlQueryUpdateConversationRead = """
        UPDATE messages SET status = 'READ'
        WHERE conversation_id = ? AND status == 'DELIVERED' AND user_id != ? AND created_at <= ?
    """
    static let sqlQueryFullMessage = """
    SELECT m.id, m.conversation_id, m.user_id, m.category, m.content, m.media_url, m.media_mime_type,
        m.media_size, m.media_duration, m.media_width, m.media_height, m.media_hash, m.media_key,
        m.media_digest, m.media_status, m.media_waveform, m.thumb_image, m.status, m.participant_id, m.snapshot_id, m.name,
        m.sticker_id, m.created_at, u.full_name as userFullName, u.identity_number as userIdentityNumber, u.app_id as appId,
               u1.full_name as participantFullName, u1.user_id as participantUserId,
               s.amount as snapshotAmount, s.asset_id as snapshotAssetId, s.type as snapshotType, a.symbol as assetSymbol, a.icon_url as assetIcon,
               st.asset_width as assetWidth, st.asset_height as assetHeight, st.asset_url as assetUrl, m.action as actionName, m.shared_user_id as sharedUserId, su.full_name as sharedUserFullName, su.identity_number as sharedUserIdentityNumber, su.avatar_url as sharedUserAvatarUrl, su.app_id as sharedUserAppId, su.is_verified as sharedUserIsVerified, m.quote_message_id, m.quote_content
    FROM messages m
    LEFT JOIN users u ON m.user_id = u.user_id
    LEFT JOIN users u1 ON m.participant_id = u1.user_id
    LEFT JOIN snapshots s ON m.snapshot_id = s.snapshot_id
    LEFT JOIN assets a ON s.asset_id = a.asset_id
    LEFT JOIN stickers st ON m.sticker_id = st.sticker_id
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
    static let sqlQueryFullMessageBeforeCreatedAt = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ? AND m.created_at < ?
    ORDER BY m.created_at DESC
    LIMIT ?
    """
    static let sqlQueryFullMessageAfterCreatedAt = """
    \(sqlQueryFullMessage)
    WHERE m.conversation_id = ? AND m.created_at > ?
    LIMIT ?
    """
    static let sqlQueryFullMessageById = sqlQueryFullMessage + " WHERE m.id = ?"
    private static let sqlQueryPendingMessages = """
    SELECT m.id, m.conversation_id, m.user_id, m.category, m.content, m.media_url, m.media_mime_type,
        m.media_size, m.media_duration, m.media_width, m.media_height, m.media_hash, m.media_key,
        m.media_digest, m.media_status, m.media_waveform, m.thumb_image, m.status, m.participant_id, m.snapshot_id, m.name,
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
    
    func getMediaUrls(likeCategory category: String) -> [String] {
        return MixinDatabase.shared.getStringValues(column: Message.Properties.mediaUrl.asColumnResult(),
                                                    tableName: Message.tableName,
                                                    condition: Message.Properties.category.like("%\(category)"),
                                                    inTransaction: false)
    }

    func deleteMessages(conversationId: String, category: String) {
        MixinDatabase.shared.delete(table: Message.tableName, condition: Message.Properties.conversationId == conversationId && Message.Properties.category.like("%\(category)"))
    }

    func findFailedMessages(conversationId: String, userId: String) -> [String] {
        return MixinDatabase.shared.getStringValues(column: Message.Properties.messageId.asColumnResult(), tableName: Message.tableName, condition: Message.Properties.conversationId == conversationId && Message.Properties.userId == userId && Message.Properties.status == MessageStatus.FAILED.rawValue, orderBy: [Message.Properties.createdAt.asOrder(by: .descending)], limit: 1000, inTransaction: false)
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
        guard MixinDatabase.shared.update(maps: [(Message.Properties.content, content), (Message.Properties.mediaStatus, mediaStatus.rawValue)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId) else {
            return
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateMediaStatus(messageId: messageId, mediaStatus: mediaStatus))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }

    func updateMessageQuoteContent(quoteMessageId: String, quoteContent: Data) {
        MixinDatabase.shared.update(maps: [(Message.Properties.quoteContent, quoteContent)], tableName: Message.tableName, condition: Message.Properties.quoteMessageId == quoteContent)
    }
    
    func updateMessageContentAndStatus(content: String, status: String, messageId: String, conversationId: String) {
        guard MixinDatabase.shared.update(maps: [(Message.Properties.content, content), (Message.Properties.status, status)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId) else {
            return
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateMessage(messageId: messageId))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }

    func updateStickerMessage(stickerData: TransferStickerData, status: String, messageId: String, conversationId: String) {
        guard MixinDatabase.shared.update(maps: [(Message.Properties.stickerId, stickerData.stickerId), (Message.Properties.status, status)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId) else {
            return
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateMessage(messageId: messageId))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }

    func updateContactMessage(transferData: TransferContactData, status: String, messageId: String, conversationId: String) {
        guard MixinDatabase.shared.update(maps: [(Message.Properties.sharedUserId, transferData.userId), (Message.Properties.status, status)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId) else {
            return
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateMessage(messageId: messageId))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }

    func updateMediaMessage(mediaData: TransferAttachmentData, status: String, messageId: String, conversationId: String, mediaStatus: MediaStatus) {
        guard MixinDatabase.shared.update(maps: [
            (Message.Properties.content, mediaData.attachmentId),
            (Message.Properties.mediaMimeType, mediaData.mimeType),
            (Message.Properties.mediaSize, mediaData.size),
            (Message.Properties.mediaDuration, mediaData.duration),
            (Message.Properties.mediaWidth, mediaData.width),
            (Message.Properties.mediaHeight, mediaData.height),
            (Message.Properties.thumbImage, mediaData.thumbnail),
            (Message.Properties.mediaKey, mediaData.key),
            (Message.Properties.mediaDigest, mediaData.digest),
            (Message.Properties.mediaStatus, mediaStatus.rawValue),
            (Message.Properties.mediaWaveform, mediaData.waveform),
            (Message.Properties.status, status),
            (Message.Properties.name, mediaData.name)
            ], tableName: Message.tableName, condition: Message.Properties.messageId == messageId) else {
            return
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateMessage(messageId: messageId))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }

    func isExist(messageId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Message.self, condition: Message.Properties.messageId == messageId)
    }

    @discardableResult
    func updateMessageStatus(messageId: String, status: String, updateUnseen: Bool = false) -> Bool {
        guard let oldMessage: Message = MixinDatabase.shared.getCodable(condition: Message.Properties.messageId == messageId) else {
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

    func updateMediaMessage(messageId: String, mediaUrl: String, status: MediaStatus, conversationId: String) {
        guard MixinDatabase.shared.update(maps: [(Message.Properties.mediaUrl, mediaUrl), (Message.Properties.mediaStatus, status.rawValue)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId) else {
            return
        }

        let change = ConversationChange(conversationId: conversationId, action: .updateMessage(messageId: messageId))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }

    func updateMediaStatus(messageId: String, status: MediaStatus, conversationId: String) {
        guard MixinDatabase.shared.update(maps: [(Message.Properties.mediaStatus, status.rawValue)], tableName: Message.tableName, condition: Message.Properties.messageId == messageId) else {
            return
        }

        let change = ConversationChange(conversationId: conversationId, action: .updateMediaStatus(messageId: messageId, mediaStatus: status))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
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
        return MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryFullMessageById, values: [messageId], inTransaction: false).first
    }

    func getMessage(messageId: String) -> Message? {
        return MixinDatabase.shared.getCodable(condition: Message.Properties.messageId == messageId)
    }

    func getPendingMessages() -> [Message] {
        return MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryPendingMessages, values: [AccountAPI.shared.accountUserId], inTransaction: false)
    }
    
    func firstUnreadMessage(conversationId: String) -> Message? {
        guard hasUnreadMessage(conversationId: conversationId) else {
            return nil
        }
        let myLastMessage: Message? = MixinDatabase.shared.getCodable(condition: Message.Properties.conversationId == conversationId && Message.Properties.userId == AccountAPI.shared.accountUserId,
                                                                      orderBy: [Message.Properties.createdAt.asOrder(by: .descending)],
                                                                      inTransaction: false)
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
                                                                        orderBy: [Message.Properties.createdAt.asOrder(by: .descending)],
                                                                        inTransaction: false)
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
                                               orderBy: [Message.Properties.createdAt.asOrder(by: .ascending)],
                                               inTransaction: false)
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
        let messages: [MessageItem] = MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryFullMessageBeforeCreatedAt, values: [conversationId, location.createdAt, count], inTransaction: false)
        return messages.reversed()
    }
    
    func getMessages(conversationId: String, belowMessage location: MessageItem, count: Int) -> [MessageItem] {
        return MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryFullMessageAfterCreatedAt,
                                                values: [conversationId, location.createdAt, count], inTransaction: false)
    }

    func getFirstNMessages(conversationId: String, count: Int) -> [MessageItem] {
        return MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryFirstNMessages, values: [conversationId, count], inTransaction: false)
    }
    
    func getLastNMessages(conversationId: String, count: Int) -> [MessageItem] {
        let messages: [MessageItem] =  MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryLastNMessages, values: [conversationId, count], inTransaction: false)
        return messages.reversed()
    }
    
    func getMessages(conversationId: String, contentLike keyword: String, belowCreatedAt location: String?, limit: Int?) -> [SearchResult] {
        let properties = [
            Message.Properties.messageId.in(table: Message.tableName),
            Message.Properties.category.in(table: Message.tableName),
            Message.Properties.content.in(table: Message.tableName),
            Message.Properties.createdAt.in(table: Message.tableName),
            User.Properties.userId.in(table: User.tableName),
            User.Properties.fullName.in(table: User.tableName),
            User.Properties.avatarUrl.in(table: User.tableName),
            User.Properties.isVerified.in(table: User.tableName),
            User.Properties.appId.in(table: User.tableName)
        ]
        let joinedTable = JoinClause(with: Message.tableName)
            .join(User.tableName, with: .left)
            .on(Message.Properties.userId.in(table: Message.tableName)
                == User.Properties.userId.in(table: User.tableName))
        
        let keywordReplacement = "%\(keyword)%"
        let textMessageContainsKeyword = Message.Properties.category.in(table: Message.tableName).like("%_TEXT")
            && Message.Properties.content.in(table: Message.tableName).like(keywordReplacement)
        let dataMessageContainsKeyword = Message.Properties.category.in(table: Message.tableName).like("%_DATA")
            && Message.Properties.name.in(table: Message.tableName).like(keywordReplacement)
        let matchesKeyword = textMessageContainsKeyword || dataMessageContainsKeyword
        var condition = Message.Properties.conversationId == conversationId && matchesKeyword
        if let location = location {
            condition = condition && Message.Properties.createdAt.in(table: Message.tableName) < location
        }
        
        var stmt = StatementSelect()
            .select(properties)
            .from(joinedTable)
            .where(condition)
            .order(by: [Message.Properties.createdAt.in(table: Message.tableName).asOrder(by: .descending)])
        
        if let limit = limit {
            stmt = stmt.limit(limit)
        }
        
        return MixinDatabase.shared.getCodables(callback: { (db) -> [SearchResult] in
            var items = [SearchResult]()
            let cs = try db.prepare(stmt)
            while try cs.step() {
                var i = -1
                var autoIncrement: Int {
                    i += 1
                    return i
                }
                let item = SearchResult(conversationId: conversationId,
                                        messageId: cs.value(atIndex: autoIncrement) ?? "",
                                        category: cs.value(atIndex: autoIncrement) ?? "",
                                        content: cs.value(atIndex: autoIncrement) ?? "",
                                        createdAt: cs.value(atIndex: autoIncrement) ?? "",
                                        userId: cs.value(atIndex: autoIncrement) ?? "",
                                        fullname: cs.value(atIndex: autoIncrement) ?? "",
                                        avatarUrl: cs.value(atIndex: autoIncrement) ?? "",
                                        isVerified: cs.value(atIndex: autoIncrement) ?? false,
                                        appId: cs.value(atIndex: autoIncrement) ?? "",
                                        keyword: keyword)
                items.append(item)
            }
            return items
        })
    }
    
    func getUnreadMessagesCount(conversationId: String) -> Int {
        guard let firstUnreadMessage = self.firstUnreadMessage(conversationId: conversationId) else {
            return 0
        }
        return MixinDatabase.shared.getCount(on: Message.Properties.messageId.count(),
                                             fromTable: Message.tableName,
                                             condition: Message.Properties.conversationId == conversationId && Message.Properties.createdAt >= firstUnreadMessage.createdAt, inTransaction: false)
    }
    
    func getGalleryItems(conversationId: String, location: GalleryItem, count: Int) -> [GalleryItem] {
        assert(count != 0)
        let messages: [Message]
        let isGalleryItem = Message.Properties.category == MessageCategory.SIGNAL_IMAGE.rawValue
            || Message.Properties.category == MessageCategory.PLAIN_IMAGE.rawValue
            || Message.Properties.category == MessageCategory.SIGNAL_VIDEO.rawValue
            || Message.Properties.category == MessageCategory.PLAIN_VIDEO.rawValue
        if count > 0 {
            let condition = Message.Properties.conversationId == conversationId
                && isGalleryItem
                && Message.Properties.status != MessageStatus.FAILED.rawValue
                && !(Message.Properties.userId == AccountAPI.shared.accountUserId && Message.Properties.mediaStatus != MediaStatus.DONE.rawValue)
                && Message.Properties.createdAt > location.createdAt
            messages = MixinDatabase.shared.getCodables(condition: condition,
                                                        orderBy: [Message.Properties.createdAt.asOrder(by: .ascending)],
                                                        limit: count,
                                                        inTransaction: false)
        } else {
            let condition = Message.Properties.conversationId == conversationId
                && isGalleryItem
                && Message.Properties.status != MessageStatus.FAILED.rawValue
                && !(Message.Properties.userId == AccountAPI.shared.accountUserId && Message.Properties.mediaStatus != MediaStatus.DONE.rawValue)
                && Message.Properties.createdAt < location.createdAt
            messages = MixinDatabase.shared.getCodables(condition: condition,
                                                        orderBy: [Message.Properties.createdAt.asOrder(by: .descending)],
                                                        limit: -count,
                                                        inTransaction: false).reversed()
        }
        return messages.compactMap(GalleryItem.init)
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
    
    @discardableResult
    func deleteMessage(id: String) -> Bool {
        return MixinDatabase.shared.delete(table: Message.tableName, condition: Message.Properties.messageId == id) > 0
    }

    func hasSentMessage(toUserId userId: String) -> Bool {
        let myId = AccountAPI.shared.accountUserId
        let conversationId = ConversationDAO.shared.makeConversationId(userId: myId, ownerUserId: userId)
        return MixinDatabase.shared.isExist(type: Message.self, condition: Message.Properties.conversationId == conversationId && Message.Properties.userId == myId, inTransaction: false)
    }
    
    func hasUnreadMessage(conversationId: String) -> Bool {
        let condition: Condition = Message.Properties.conversationId == conversationId
            && Message.Properties.status == MessageStatus.DELIVERED.rawValue
            && Message.Properties.userId != AccountAPI.shared.accountUserId
        return MixinDatabase.shared.isExist(type: Message.self, condition: condition, inTransaction: false)
    }
    
    func hasMessage(id: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Message.self, condition: Message.Properties.messageId == id, inTransaction: false)
    }

    func getQuoteMessage(messageId: String?) -> Data? {
        guard let quoteMessageId = messageId, let quoteMessage: MessageItem = MixinDatabase.shared.getCodables(sql: MessageDAO.sqlQueryQuoteMessageById, values: [quoteMessageId], inTransaction: false).first else {
            return nil
        }
        return try? JSONEncoder().encode(quoteMessage)
    }

}
