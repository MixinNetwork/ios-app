import GRDB

public final class ConversationDAO: UserDatabaseDAO {
    
    public static let shared = ConversationDAO()
    
    public static let willClearConversationNotification = Notification.Name("one.mixin.service.ConversationDAO.willClearConversation")
    public static let conversationIdUserInfoKey = "cid"
    
    private static let sqlQueryColumns = """
    SELECT c.conversation_id as conversationId, c.owner_id as ownerId, c.icon_url as iconUrl,
    c.announcement as announcement, c.category as category, c.name as name, c.status as status,
    c.last_read_message_id as lastReadMessageId, c.unseen_message_count as unseenMessageCount,
    (SELECT COUNT(*) FROM message_mentions mm WHERE mm.conversation_id = c.conversation_id AND mm.has_read = 0) as unseenMentionCount,
    CASE WHEN c.category = 'CONTACT' THEN u1.mute_until ELSE c.mute_until END as muteUntil,
    c.code_url as codeUrl, c.pin_time as pinTime, c.expire_in as expireIn,
    m.content as content, m.category as contentType, em.expire_in as contentExpireIn, m.created_at as createdAt,
    m.user_id as senderId, u.full_name as senderFullName, u1.identity_number as ownerIdentityNumber,
    u1.full_name as ownerFullName, u1.avatar_url as ownerAvatarUrl, u1.is_verified as ownerIsVerified,
    m.action as actionName, u2.full_name as participantFullName, u2.user_id as participantUserId, m.status as messageStatus, m.id as messageId, u1.app_id as appId,
    mm.mentions
    """
    private static let sqlQueryConversation = """
    \(sqlQueryColumns)
    FROM conversations c
    LEFT JOIN messages m ON c.last_message_id = m.id
    LEFT JOIN users u ON u.user_id = m.user_id
    LEFT JOIN users u2 ON u2.user_id = m.participant_id
    LEFT JOIN message_mentions mm ON m.id = mm.message_id
    LEFT JOIN expired_messages em ON c.last_message_id = em.message_id
    INNER JOIN users u1 ON u1.user_id = c.owner_id
    WHERE c.category IS NOT NULL %@
    ORDER BY %@c.pin_time DESC, c.last_message_created_at DESC
    """
    private static let sqlQueryConversationByCoversationId = String(format: sqlQueryConversation, " AND c.conversation_id = ? ", "")
    
    public func hasUnreadMessage(outsideCircleWith id: String) -> Bool {
        let sql = """
            SELECT 1 FROM conversations
            WHERE conversation_id NOT IN (
                SELECT conversation_id FROM circle_conversations WHERE circle_id = ?
            ) AND unseen_message_count > 0
            LIMIT 1
        """
        let value: Int64 = db.select(with: sql, arguments: [id]) ?? 0
        return value > 0
    }
    
    public func getUnreadMessageCount() -> Int {
        let sql = "SELECT ifnull(SUM(unseen_message_count),0) FROM conversations WHERE category IS NOT NULL"
        return db.select(with: sql) ?? 0
    }
    
    public func getUnreadMessageCountWithoutMuted() -> Int {
        let sql = """
        SELECT ifnull(SUM(unseen_message_count),0) FROM (
            SELECT c.unseen_message_count, CASE WHEN c.category = 'CONTACT' THEN u.mute_until ELSE c.mute_until END as muteUntil
            FROM conversations c
            INNER JOIN users u ON u.user_id = c.owner_id
            WHERE muteUntil < ?
        )
        """
        return db.select(with: sql, arguments: [Date().toUTCString()]) ?? 0
    }
    
    public func getCategoryStorages(conversationId: String) -> [ConversationCategoryStorage] {
        let sql = """
        SELECT category, sum(media_size) as mediaSize, count(id) as messageCount FROM messages
        WHERE conversation_id = ? AND media_status = 'DONE' GROUP BY category
        """
        return db.select(with: sql, arguments: [conversationId])
    }
    
    public func storageUsageConversations() -> [ConversationStorageUsage] {
        let sql = """
        SELECT c.conversation_id as conversationId, c.owner_id as ownerId, c.category, c.icon_url as iconUrl, c.name, u.identity_number as ownerIdentityNumber,
        u.full_name as ownerFullName, u.avatar_url as ownerAvatarUrl, u.is_verified as ownerIsVerified, m.mediaSize
        FROM conversations c
        INNER JOIN (SELECT conversation_id, sum(media_size) as mediaSize FROM messages WHERE media_status = 'DONE' GROUP BY conversation_id) m
            ON m.conversation_id = c.conversation_id
        INNER JOIN users u ON u.user_id = c.owner_id
        ORDER BY m.mediaSize DESC
        """
        return db.select(with: sql)
    }
    
    public func isExist(conversationId: String) -> Bool {
        db.recordExists(in: Conversation.self,
                        where: Conversation.column(of: .conversationId) == conversationId)
    }
    
    public func getExpireIn(conversationId: String) -> Int64? {
        db.select(column: Conversation.column(of: .expireIn),
                  from: Conversation.self,
                  where: Conversation.column(of: .conversationId) == conversationId)
    }
    
    public func updateExpireIn(expireIn: Int64, conversationId: String) {
        db.update(Conversation.self,
                  assignments: [Conversation.column(of: .expireIn).set(to: expireIn)],
                  where: Conversation.column(of: .conversationId) == conversationId) { _ in
            let change = ConversationChange(conversationId: conversationId,
                                            action: .updateExpireIn(expireIn: expireIn, messageId: nil))
            NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
        }
    }
    
    public func updateCodeUrl(conversation: ConversationResponse) {
        db.update(Conversation.self,
                  assignments: [Conversation.column(of: .codeUrl).set(to: conversation.codeUrl)],
                  where: Conversation.column(of: .conversationId) == conversation.conversationId) { _ in
            let change = ConversationChange(conversationId: conversation.conversationId,
                                            action: .updateConversation(conversation: conversation))
            NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
        }
    }
    
    public func getConversationIconUrl(conversationId: String) -> String? {
        return db.select(column: Conversation.column(of: .iconUrl),
                         from: Conversation.self,
                         where: Conversation.column(of: .conversationId) == conversationId)
    }
    
    public func updateIconUrl(conversationId: String, iconUrl: String) {
        db.update(Conversation.self,
                  assignments: [Conversation.column(of: .iconUrl).set(to: iconUrl)],
                  where: Conversation.column(of: .conversationId) == conversationId)
    }
    
    public func getStartStatusConversations() -> [String] {
        return db.select(column: Conversation.column(of: .conversationId),
                         from: Conversation.self,
                         where: Conversation.column(of: .status) == ConversationStatus.START.rawValue)
    }
    
    public func updateConversationOwnerId(conversationId: String, ownerId: String) -> Bool {
        db.update(Conversation.self,
                  assignments: [Conversation.column(of: .ownerId).set(to: ownerId)],
                  where: Conversation.column(of: .conversationId) == conversationId)
    }
    
    public func updateConversationMuteUntil(conversationId: String, muteUntil: String) {
        db.update(Conversation.self,
                  assignments: [Conversation.column(of: .muteUntil).set(to: muteUntil)],
                  where: Conversation.column(of: .conversationId) == conversationId) { _ in
            guard let conversation = self.getConversation(conversationId: conversationId) else {
                return
            }
            let change = ConversationChange(conversationId: conversationId,
                                            action: .update(conversation: conversation))
            NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
        }
    }
    
    public func updateConversation(with conversationId: String, inCirleOf circleId: String?, pinTime: String?) {
        if let circleId = circleId {
            let condition = CircleConversation.column(of: .circleId) == circleId
                && CircleConversation.column(of: .conversationId) == conversationId
            db.update(CircleConversation.self,
                      assignments: [CircleConversation.column(of: .pinTime).set(to: pinTime)],
                      where: condition)
        } else {
            db.update(Conversation.self,
                      assignments: [Conversation.column(of: .pinTime).set(to: pinTime)],
                      where: Conversation.column(of: .conversationId) == conversationId)
        }
    }
    
    public func updateLastReadMessageId(_ messageId: String, conversationId: String, database: GRDB.Database) throws {
        try Conversation
            .filter(Conversation.column(of: .conversationId) == conversationId)
            .updateAll(database, [Conversation.column(of: .lastReadMessageId).set(to: messageId)])
    }
    
    public func exitGroup(conversationId: String) {
        db.write { db in
            let assignments = [
                Conversation.column(of: .unseenMessageCount).set(to: 0),
                Conversation.column(of: .status).set(to: ConversationStatus.QUIT.rawValue)
            ]
            try Conversation
                .filter(Conversation.column(of: .conversationId) == conversationId)
                .updateAll(db, assignments)
            try ParticipantSession
                .filter(ParticipantSession.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            try Participant
                .filter(Participant.column(of: .conversationId) == conversationId && Participant.column(of: .userId) == myUserId)
                .deleteAll(db)
            db.afterNextTransaction { (_) in
                NotificationCenter.default.post(onMainThread: ParticipantDAO.participantDidChangeNotification,
                                                object: self,
                                                userInfo: [ParticipantDAO.UserInfoKey.conversationId: conversationId])
                let change = ConversationChange(conversationId: conversationId,
                                                action: .updateConversationStatus(status: .QUIT))
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
            }
        }
    }
    
    public func deleteChat(conversationId: String) {
        let mediaUrls = MessageDAO.shared.getMediaUrls(conversationId: conversationId, categories: MessageCategory.allMediaCategories)
        let shouldCleanUpWallpaper = shouldCleanUpWallpaper(conversationId: conversationId)
        db.write { db in
            let deletedTranscriptIds = try deleteTranscriptChildrenReferenced(by: conversationId, from: db)
            try Message
                .filter(Message.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            try MessageMention
                .filter(MessageMention.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            try Conversation
                .filter(Conversation.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            try Participant
                .filter(Participant.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            try ParticipantSession
                .filter(ParticipantSession.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            try deleteFTSContent(with: conversationId, from: db)
            try PinMessageDAO.shared.deleteAll(conversationId: conversationId, from: db)
            db.afterNextTransaction { (_) in
                let job = AttachmentCleanUpJob(conversationId: conversationId,
                                               mediaUrls: mediaUrls,
                                               transcriptIds: deletedTranscriptIds)
                ConcurrentJobQueue.shared.addJob(job: job)
                if shouldCleanUpWallpaper {
                    AppGroupUserDefaults.User.wallpapers[conversationId] = nil
                    let url = AttachmentContainer.wallpaperURL(for: conversationId)
                    try? FileManager.default.removeItem(at: url)
                }
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: nil)
            }
        }
    }
    
    public func clearChat(conversationId: String) {
        let mediaUrls = MessageDAO.shared.getMediaUrls(conversationId: conversationId, categories: MessageCategory.allMediaCategories)
        db.write { db in
            let deletedTranscriptIds = try deleteTranscriptChildrenReferenced(by: conversationId, from: db)
            NotificationCenter.default.post(onMainThread: Self.willClearConversationNotification,
                                            object: self,
                                            userInfo: [Self.conversationIdUserInfoKey: conversationId])
            try Message
                .filter(Message.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            try MessageMention
                .filter(MessageMention.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            let assignments = [
                Conversation.column(of: .unseenMessageCount).set(to: 0),
                Conversation.column(of: .lastMessageId).set(to: nil),
                Conversation.column(of: .lastMessageCreatedAt).set(to: nil),
                Conversation.column(of: .lastReadMessageId).set(to: nil)
            ]
            try Conversation
                .filter(Conversation.column(of: .conversationId) == conversationId)
                .updateAll(db, assignments)
            try deleteFTSContent(with: conversationId, from: db)
            try PinMessageDAO.shared.deleteAll(conversationId: conversationId, from: db)
            db.afterNextTransaction { (_) in
                let job = AttachmentCleanUpJob(conversationId: conversationId,
                                               mediaUrls: mediaUrls,
                                               transcriptIds: deletedTranscriptIds)
                ConcurrentJobQueue.shared.addJob(job: job)
                let change = ConversationChange(conversationId: conversationId, action: .reload)
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
            }
        }
    }
    
    public func getConversation(conversationId: String) -> ConversationItem? {
        guard !conversationId.isEmpty else {
            return nil
        }
        return db.select(with: ConversationDAO.sqlQueryConversationByCoversationId,
                         arguments: [conversationId])
    }
    
    public func getGroupOrStrangerConversation(withNameLike keyword: String, limit: Int?) -> [ConversationItem] {
        let condition = "AND ((c.category = 'GROUP' AND c.name LIKE :escaped ESCAPE '/') OR (c.category = 'CONTACT' AND u1.relationship = 'STRANGER' AND u1.full_name LIKE :escaped ESCAPE '/'))"
        let order = "(c.category = 'GROUP' AND c.name = :raw COLLATE NOCASE) OR (c.category = 'CONTACT' AND u1.full_name = :raw COLLATE NOCASE) DESC, "
        var sql = String(format: Self.sqlQueryConversation, condition, order)
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        let arguments = ["escaped": "%\(keyword.sqlEscaped)%", "raw": keyword]
        return db.select(with: sql, arguments: StatementArguments(arguments))
    }
    
    public func getConversationStatus(conversationId: String) -> Int? {
        db.select(column: Conversation.column(of: .status),
                  from: Conversation.self,
                  where: Conversation.column(of: .conversationId) == conversationId)
    }
    
    public func getConversationCategory(conversationId: String) -> String? {
        db.select(column: Conversation.column(of: .category),
                  from: Conversation.self,
                  where: Conversation.column(of: .conversationId) == conversationId)
    }
    
    public func conversationList(limit: Int? = nil, circleId: String? = nil) -> [ConversationItem] {
        var sql: String
        if circleId == nil {
            sql = String(format: Self.sqlQueryConversation, "", "")
        } else {
            sql = """
                SELECT c.conversation_id as conversationId, c.owner_id as ownerId, c.icon_url as iconUrl,
                c.announcement as announcement, c.category as category, c.name as name, c.status as status,
                c.last_read_message_id as lastReadMessageId, c.unseen_message_count as unseenMessageCount,
                (SELECT COUNT(*) FROM message_mentions mm WHERE mm.conversation_id = c.conversation_id AND mm.has_read = 0) as unseenMentionCount,
                CASE WHEN c.category = 'CONTACT' THEN u1.mute_until ELSE c.mute_until END as muteUntil,
                c.code_url as codeUrl, cc.pin_time as pinTime, c.expire_in as expireIn,
                m.content as content, m.category as contentType, em.expire_in as contentExpireIn, m.created_at as createdAt,
                m.user_id as senderId, u.full_name as senderFullName, u1.identity_number as ownerIdentityNumber,
                u1.full_name as ownerFullName, u1.avatar_url as ownerAvatarUrl, u1.is_verified as ownerIsVerified,
                m.action as actionName, u2.full_name as participantFullName, u2.user_id as participantUserId,
                m.status as messageStatus, m.id as messageId, u1.app_id as appId,
                mm.mentions
                FROM conversations c
                LEFT JOIN messages m ON c.last_message_id = m.id
                LEFT JOIN users u ON u.user_id = m.user_id
                LEFT JOIN users u2 ON u2.user_id = m.participant_id
                LEFT JOIN message_mentions mm ON m.id = mm.message_id
                LEFT JOIN expired_messages em ON c.last_message_id = em.message_id
                INNER JOIN users u1 ON u1.user_id = c.owner_id
                INNER JOIN circle_conversations cc ON cc.conversation_id = c.conversation_id
                WHERE c.category IS NOT NULL AND cc.circle_id = ?
                ORDER BY cc.pin_time DESC, c.last_message_created_at DESC
            """
        }
        if let limit = limit {
            sql = sql + " LIMIT \(limit)"
        }
        if let id = circleId {
            return db.select(with: sql, arguments: [id])
        } else {
            return db.select(with: sql)
        }
    }
    
    public func groupsInCommon(userId: String) -> [GroupInCommon] {
        let sql = """
        SELECT c.conversation_id, c.icon_url, c.name, (SELECT count(user_id) from participants where conversation_id = c.conversation_id) AS participantsCount
        FROM participants p
        INNER JOIN conversations c ON c.conversation_id = p.conversation_id
        WHERE p.user_id IN (?, ?)
        AND c.status = ?
        AND c.category = 'GROUP'
        GROUP BY c.conversation_id
        HAVING count(p.user_id) = 2
        ORDER BY c.last_message_created_at DESC
        """
        return db.select(with: sql, arguments: [myUserId, userId, ConversationStatus.SUCCESS.rawValue])
    }
    
    public func createPlaceConversation(conversationId: String, ownerId: String) {
        guard !conversationId.isEmpty else {
            return
        }
        let conversationExists = db.recordExists(in: Conversation.self,
                                                 where: Conversation.column(of: .conversationId) == conversationId)
        guard !conversationExists else {
            return
        }
        let conversation = Conversation.createConversation(conversationId: conversationId, category: nil, recipientId: ownerId, status: ConversationStatus.START.rawValue)
        db.save(conversation)
    }
    
    public func createConversation(conversationId: String, name: String, members: [GroupUser], completion: @escaping (_ success: Bool) -> Void) {
        let createdAt = Date().toUTCString()
        let conversation = Conversation(conversationId: conversationId,
                                        ownerId: myUserId,
                                        category: ConversationCategory.GROUP.rawValue,
                                        name: name,
                                        iconUrl: nil,
                                        announcement: nil,
                                        lastMessageId: nil,
                                        lastMessageCreatedAt: nil,
                                        lastReadMessageId: nil,
                                        unseenMessageCount: 0,
                                        status: ConversationStatus.START.rawValue,
                                        draft: nil,
                                        muteUntil: nil,
                                        codeUrl: nil,
                                        pinTime: nil,
                                        expireIn: 0,
                                        createdAt: createdAt)
        var participants = members.map {
            Participant(conversationId: conversationId,
                        userId: $0.userId,
                        role: "",
                        status: ParticipantStatus.SUCCESS.rawValue,
                        createdAt: createdAt)
        }
        let me = Participant(conversationId: conversationId,
                             userId: myUserId,
                             role: ParticipantRole.OWNER.rawValue,
                             status: ParticipantStatus.SUCCESS.rawValue,
                             createdAt: createdAt)
        participants.append(me)
        
        do {
            try db.writeAndReturnError { (db) -> Void in
                try conversation.insert(db)
                try participants.save(db)
                db.afterNextTransaction { (_) in
                    // Avoid potential deadlock
                    // TODO: Nested transactions could be auto detected, make some assertion?
                    DispatchQueue.global().async {
                        completion(true)
                    }
                }
            }
        } catch {
            Logger.general.error(category: "ConversationDAO", message: "Failed to save new created conversation: \(error)")
            completion(false)
        }
    }
    
    public func createNewConversation(response: ConversationResponse) -> (ConversationItem, [ParticipantUser]) {
        let conversationId = response.conversationId
        var conversation: ConversationItem!
        var participantUsers = [ParticipantUser]()
        
        db.write { (db) in
            try Conversation.createConversation(from: response, ownerId: myUserId, status: .SUCCESS).insert(db)
            let participants = response.participants.map {
                Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.SUCCESS.rawValue, createdAt: $0.createdAt)
            }
            try participants.insert(db)
            if let participantSessions = response.participantSessions {
                let createdAt = Date().toUTCString()
                let sessions = participantSessions.map { session in
                    ParticipantSession(conversationId: conversationId,
                                       userId: session.userId,
                                       sessionId: session.sessionId,
                                       sentToServer: nil,
                                       createdAt: createdAt,
                                       publicKey: session.publicKey)
                }
                try sessions.save(db)
            }
            conversation = try ConversationItem.fetchOne(db, sql: ConversationDAO.sqlQueryConversationByCoversationId, arguments: [conversationId], adapter: nil)
            participantUsers = try ParticipantUser.fetchAll(db, sql: ParticipantDAO.sqlQueryGroupIconParticipants, arguments: [conversationId], adapter: nil)
        }
        
        return (conversation, participantUsers)
    }
    
    @discardableResult
    public func createConversation(conversation: ConversationResponse, targetStatus: ConversationStatus) -> ConversationItem? {
        var ownerId = conversation.creatorId
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            if let ownerParticipant = conversation.participants.first(where: { (participant) -> Bool in
                return participant.userId != myUserId
            }) {
                ownerId = ownerParticipant.userId
            }
        }
        
        let conversationId = conversation.conversationId
        var resultConversation: ConversationItem?
        db.write { (db) in
            let request = try Conversation
                .select(Conversation.column(of: .status))
                .filter(Conversation.column(of: .conversationId) == conversationId)
            let oldStatus: Int? = try Row.fetchOne(db, request)?[0]
            
            guard oldStatus != targetStatus.rawValue else {
                return
            }
            
            if oldStatus == nil {
                let targetConversation = Conversation.createConversation(from: conversation,
                                                                         ownerId: ownerId,
                                                                         status: targetStatus)
                try targetConversation.insert(db)
            } else {
                let assignments = [
                    Conversation.column(of: .ownerId).set(to: ownerId),
                    Conversation.column(of: .category).set(to: conversation.category),
                    Conversation.column(of: .name).set(to: conversation.name),
                    Conversation.column(of: .announcement).set(to: conversation.announcement),
                    Conversation.column(of: .status).set(to: targetStatus.rawValue),
                    Conversation.column(of: .muteUntil).set(to: conversation.muteUntil),
                    Conversation.column(of: .codeUrl).set(to: conversation.codeUrl),
                    Conversation.column(of: .expireIn).set(to: conversation.expireIn)
                ]
                try Conversation
                    .filter(Conversation.column(of: .conversationId) == conversationId)
                    .updateAll(db, assignments)
            }
            
            if conversation.participants.count > 0 {
                let participants = conversation.participants.map {
                    Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.START.rawValue, createdAt: $0.createdAt)
                }
                try participants.save(db)
                
                if conversation.category == ConversationCategory.GROUP.rawValue {
                    let creatorId = conversation.creatorId
                    if !conversation.participants.contains(where: { $0.userId == creatorId }) {
                        ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [creatorId]))
                    }
                }
            }
            
            if let participantSessions = conversation.participantSessions, participantSessions.count > 0 {
                let sessionParticipants = participantSessions.map {
                    ParticipantSession(conversationId: conversationId,
                                       userId: $0.userId,
                                       sessionId: $0.sessionId,
                                       sentToServer: nil,
                                       createdAt: Date().toUTCString(),
                                       publicKey: $0.publicKey)
                }
                try sessionParticipants.save(db)
            }
            
            let userIds = try ParticipantDAO.shared.getNeedSyncParticipantIds(database: db, conversationId: conversationId)
            if userIds.count > 0 {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: userIds))
            }
            
            resultConversation = try ConversationItem.fetchOne(db, sql: ConversationDAO.sqlQueryConversationByCoversationId, arguments: [conversationId], adapter: nil)
            
            db.afterNextTransaction { (_) in
                let change = ConversationChange(conversationId: conversationId,
                                                action: .updateConversation(conversation: conversation))
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
            }
        }
        return resultConversation
    }
    
    public func updateConversation(conversation: ConversationResponse) {
        let conversationId = conversation.conversationId
        var ownerId = conversation.creatorId
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            if let ownerParticipant = conversation.participants.first(where: { (participant) -> Bool in
                return participant.userId != myUserId
            }) {
                ownerId = ownerParticipant.userId
            }
        }
        
        guard let oldConversation: Conversation = db.select(where: Conversation.column(of: .conversationId) == conversationId) else {
            return
        }
        
        if oldConversation.announcement != conversation.announcement, !conversation.announcement.isEmpty {
            AppGroupUserDefaults.User.hasUnreadAnnouncement[conversationId] = true
        }
        let status: ConversationStatus
        if conversation.category == ConversationCategory.GROUP.rawValue && !conversation.participants.contains { $0.userId == myUserId } {
            status = .QUIT
        } else {
            status = .SUCCESS
        }
        db.write { (db) in
            try Participant
                .filter(Participant.column(of: .conversationId) == conversationId)
                .deleteAll(db)
            let participants = conversation.participants.map {
                Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.START.rawValue, createdAt: $0.createdAt)
            }
            try participants.save(db)
            try ParticipantSessionDAO.shared.syncConversationParticipantSession(conversation: conversation, db: db)
            try db.execute(sql: ParticipantDAO.sqlUpdateStatus, arguments: [conversationId])
            let assignments = [
                Conversation.column(of: .ownerId).set(to: ownerId),
                Conversation.column(of: .category).set(to: conversation.category),
                Conversation.column(of: .name).set(to: conversation.name),
                Conversation.column(of: .announcement).set(to: conversation.announcement),
                Conversation.column(of: .status).set(to: status.rawValue),
                Conversation.column(of: .muteUntil).set(to: conversation.muteUntil),
                Conversation.column(of: .codeUrl).set(to: conversation.codeUrl),
                Conversation.column(of: .expireIn).set(to: conversation.expireIn),
            ]
            try Conversation
                .filter(Conversation.column(of: .conversationId) == conversationId)
                .updateAll(db, assignments)
            
            let userIds = try ParticipantDAO.shared.getNeedSyncParticipantIds(database: db, conversationId: conversationId)
            if userIds.count > 0 {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: userIds))
            }
            
            db.afterNextTransaction { (_) in
                if oldConversation.status != status.rawValue {
                    let change = ConversationChange(conversationId: conversationId,
                                                    action: .updateConversationStatus(status: status))
                    NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
                }
                let change = ConversationChange(conversationId: conversationId,
                                                action: .updateConversation(conversation: conversation))
                NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: change)
            }
        }
    }
    
    public func makeConversationId(userId: String, ownerUserId: String) -> String {
        let merged = min(userId, ownerUserId) + max(userId, ownerUserId)
        return merged.uuidDigest()
    }
    
    public func updateLastMessageIdOnInsertMessage(conversationId: String, messageId: String, createdAt: String, database: GRDB.Database) throws {
        let sql = """
        UPDATE conversations SET last_message_id = ?, last_message_created_at = ?
        WHERE conversation_id = ? AND (last_message_created_at ISNULL OR ? >= last_message_created_at)
        """
        try database.execute(sql: sql, arguments: [messageId, createdAt, conversationId, createdAt])
    }
    
    public func updateLastMessageIdAndCreatedAt() {
        db.write { db in
            let updateLastMessageIdSQL = """
            UPDATE conversations
            SET last_message_id = (
                SELECT id
                FROM messages
                WHERE conversation_id = conversations.conversation_id
                ORDER BY created_at DESC
                LIMIT 1
            )
            """
            try db.execute(sql: updateLastMessageIdSQL)
            
            let updateLastMessageCreatedAtSQL = """
            UPDATE conversations
            SET last_message_created_at = (
                SELECT created_at
                FROM messages
                WHERE id = conversations.last_message_id
                LIMIT 1
            )
            """
            try db.execute(sql: updateLastMessageCreatedAtSQL)
        }
    }
    
    public func updateLastMessageIdOnDeleteMessage(conversationId: String, messageId: String? = nil, database: GRDB.Database) throws {
        var sql = "UPDATE conversations SET last_message_id = (SELECT id FROM messages WHERE conversation_id = ? ORDER BY created_at DESC LIMIT 1)"
        let arguments: StatementArguments
        if let messageId = messageId {
            // Reduce redundant updating to conversation table by checking whether `last_message_id` matches or not.
            sql += " WHERE conversation_id = ? AND last_message_id = ?"
            arguments = [conversationId, conversationId, messageId]
        } else {
            sql += " WHERE conversation_id = ?"
            arguments = [conversationId, conversationId]
        }
        try database.execute(sql: sql, arguments: arguments)
        database.afterNextTransaction { db in
            NotificationCenter.default.post(onMainThread: conversationDidChangeNotification, object: nil)
        }
    }
    
    public func conversations(limit: Int, after conversationId: String?, matching conversationIDs: [String]?) -> [Conversation] {
        if let conversationIDs {
            var totalConversations = [Conversation]()
            for i in stride(from: 0, to: conversationIDs.count, by: Self.strideForDeviceTransfer) {
                let endIndex = min(i + Self.strideForDeviceTransfer, conversationIDs.count)
                let ids = Array(conversationIDs[i..<endIndex]).joined(separator: "', '")
                var sql = "SELECT * FROM conversations WHERE conversation_id in ('\(ids)')"
                if let conversationId {
                    sql += " AND ROWID > IFNULL((SELECT ROWID FROM conversations WHERE conversation_id = '\(conversationId)'), 0)"
                }
                sql += " ORDER BY ROWID LIMIT ?"
                let conversations: [Conversation] = db.select(with: sql, arguments: [limit])
                totalConversations += conversations
            }
            return totalConversations
        } else {
            var sql = "SELECT * FROM conversations"
            if let conversationId {
                sql += " WHERE ROWID > IFNULL((SELECT ROWID FROM conversations WHERE conversation_id = '\(conversationId)'), 0)"
            }
            sql += " ORDER BY ROWID LIMIT ?"
            return db.select(with: sql, arguments: [limit])
        }
    }

    public func conversationsCount(matching conversationIDs: [String]?) -> Int {
        if let conversationIDs {
            var totalCount = 0
            for i in stride(from: 0, to: conversationIDs.count, by: Self.strideForDeviceTransfer) {
                let endIndex = min(i + Self.strideForDeviceTransfer, conversationIDs.count)
                let ids = Array(conversationIDs[i..<endIndex]).joined(separator: "', '")
                let sql = "SELECT COUNT(*) FROM conversations WHERE conversation_id in ('\(ids)')"
                let count: Int? = db.select(with: sql)
                totalCount += (count ?? 0)
            }
            return totalCount
        } else {
            let count: Int? = db.select(with: "SELECT COUNT(*) FROM conversations")
            return count ?? 0
        }
    }
    
    public func save(conversation: Conversation) {
        let unseenMessageCount: Int? = db.select(column: Conversation.column(of: .unseenMessageCount),
                                                 from: Conversation.self,
                                                 where: Conversation.column(of: .conversationId) == conversation.conversationId)
        var conversation = conversation
        conversation.unseenMessageCount = unseenMessageCount ?? 0
        db.save(conversation)
    }
    
}

extension ConversationDAO {
    
    private func deleteFTSContent(with conversationId: String, from db: GRDB.Database) throws {
        let sql = "DELETE FROM \(Message.ftsTableName) WHERE conversation_id MATCH ?"
        try db.execute(sql: sql, arguments: [uuidTokenString(uuidString: conversationId)])
    }
    
    private func deleteTranscriptChildrenReferenced(by conversationId: String, from db: GRDB.Database) throws -> [String] {
        let transcriptMessageIds = try MessageDAO.shared.getTranscriptMessageIds(conversationId: conversationId, database: db)
        for id in transcriptMessageIds {
            try TranscriptMessage
                .filter(TranscriptMessage.column(of: .transcriptId) == id)
                .deleteAll(db)
        }
        return transcriptMessageIds
    }
    
    private func shouldCleanUpWallpaper(conversationId: String) -> Bool {
        let sql = """
            SELECT 1
            FROM conversations c
            INNER JOIN users u ON u.user_id = c.owner_id
            WHERE (c.conversation_id = ?) AND ((c.category = ? AND c.status = ?) OR (c.category = ? AND u.relationship != ?))
            LIMIT 1
        """
        let arguments: StatementArguments = [
            conversationId,
            ConversationCategory.GROUP.rawValue,
            ConversationStatus.QUIT.rawValue,
            ConversationCategory.CONTACT.rawValue,
            Relationship.FRIEND.rawValue
        ]
        let value: Int64 = db.select(with: sql, arguments: arguments) ?? 0
        return value != 0
    }
    
}
