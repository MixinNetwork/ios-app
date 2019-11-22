import WCDBSwift

final class ConversationDAO {

    static let shared = ConversationDAO()

    private static let sqlQueryColumns = """
    SELECT c.conversation_id as conversationId, c.owner_id as ownerId, c.icon_url as iconUrl,
    c.announcement as announcement, c.category as category, c.name as name, c.status as status,
    c.last_read_message_id as lastReadMessageId, c.unseen_message_count as unseenMessageCount,
    CASE WHEN c.category = 'CONTACT' THEN u1.mute_until ELSE c.mute_until END as muteUntil,
    c.code_url as codeUrl, c.pin_time as pinTime,
    m.content as content, m.category as contentType, m.created_at as createdAt,
    m.user_id as senderId, u.full_name as senderFullName, u1.identity_number as ownerIdentityNumber,
    u1.full_name as ownerFullName, u1.avatar_url as ownerAvatarUrl, u1.is_verified as ownerIsVerified,
    m.action as actionName, u2.full_name as participantFullName, u2.user_id as participantUserId, m.status as messageStatus, m.id as messageId, u1.app_id as appId
    """
    private static let sqlQueryConversation = """
    \(sqlQueryColumns)
    FROM conversations c
    LEFT JOIN messages m ON c.last_message_id = m.id
    LEFT JOIN users u ON u.user_id = m.user_id
    LEFT JOIN users u2 ON u2.user_id = m.participant_id
    INNER JOIN users u1 ON u1.user_id = c.owner_id
    WHERE c.category IS NOT NULL AND c.status <> 2 %@
    ORDER BY c.pin_time DESC, c.last_message_created_at DESC
    """
    private static let sqlQueryConversationList = String(format: sqlQueryConversation, "")
    private static let sqlQueryConversationByOwnerId = String(format: sqlQueryConversation, " AND c.owner_id = ? AND c.category = 'CONTACT'")
    private static let sqlQueryConversationByCoversationId = String(format: sqlQueryConversation, " AND c.conversation_id = ? ")
    private static let sqlQueryGroupOrStrangerConversationByName = String(format: sqlQueryConversation, " AND ((c.category = 'GROUP' AND c.name LIKE ? ESCAPE '/') OR (c.category = 'CONTACT' AND u1.relationship = 'STRANGER' AND u1.full_name LIKE ? ESCAPE '/'))")
    private static let sqlQueryStorageUsage = """
    SELECT c.conversation_id as conversationId, c.owner_id as ownerId, c.category, c.icon_url as iconUrl, c.name, u.identity_number as ownerIdentityNumber,
    u.full_name as ownerFullName, u.avatar_url as ownerAvatarUrl, u.is_verified as ownerIsVerified, m.mediaSize
    FROM conversations c
    INNER JOIN (SELECT conversation_id, sum(media_size) as mediaSize FROM messages WHERE ifnull(media_size,'') != '' GROUP BY conversation_id) m
        ON m.conversation_id = c.conversation_id
    INNER JOIN users u ON u.user_id = c.owner_id
    ORDER BY m.mediaSize DESC
    """
    private static let sqlQueryConversationStorageUsage = """
    SELECT category, sum(media_size) as mediaSize, count(id) as messageCount  FROM messages
    WHERE conversation_id = ? AND ifnull(media_size,'') != '' GROUP BY category
    """
    private static let sqlBadgeNumber = """
    SELECT ifnull(SUM(unseen_message_count),0) FROM (
        SELECT c.unseen_message_count, CASE WHEN c.category = 'CONTACT' THEN u.mute_until ELSE c.mute_until END as muteUntil
        FROM conversations c
        INNER JOIN users u ON u.user_id = c.owner_id
        WHERE muteUntil < ?
    )
    """
    private static let sqlSearchMessages = """
    SELECT m.conversation_id, c.category,
    CASE c.category WHEN 'CONTACT' THEN u.full_name ELSE c.name END,
    CASE c.category WHEN 'CONTACT' THEN u.avatar_url ELSE c.icon_url END,
    CASE c.category WHEN 'CONTACT' THEN u.user_id ELSE NULL END,
    u.is_verified, u.app_id, COUNT(m.conversation_id)
    FROM messages m
    LEFT JOIN conversations c ON m.conversation_id = c.conversation_id
    LEFT JOIN users u ON c.owner_id = u.user_id
    WHERE m.category in ('SIGNAL_TEXT', 'SIGNAL_DATA','PLAIN_TEXT','PLAIN_DATA') AND m.status != 'FAILED'
    AND (m.content LIKE ? ESCAPE '/' OR m.name LIKE ? ESCAPE '/')
    GROUP BY m.conversation_id
    ORDER BY c.pin_time DESC, c.last_message_created_at DESC
    """
    
    func showBadgeNumber() {
        DispatchQueue.global().async {
            var badgeNumber = Int(MixinDatabase.shared.scalar(sql: ConversationDAO.sqlBadgeNumber, values: [Date().toUTCString()]).int32Value)
            if badgeNumber > 99 {
                badgeNumber = 99
            }

            DispatchQueue.main.async {
                if badgeNumber != UIApplication.shared.applicationIconBadgeNumber {
                    UIApplication.shared.applicationIconBadgeNumber = badgeNumber
                }
            }
        }
    }

    func getCategoryStorages(conversationId: String) -> [ConversationCategoryStorage] {
        return MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQueryConversationStorageUsage, values: [conversationId])
    }

    func storageUsageConversations() -> [ConversationStorageUsage] {
        return MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQueryStorageUsage)
    }

    func isExist(conversationId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Conversation.self, condition: Conversation.Properties.conversationId == conversationId)
    }

    func hasValidConversation() -> Bool {
        return MixinDatabase.shared.isExist(type: Conversation.self, condition: Conversation.Properties.status != ConversationStatus.QUIT.rawValue)
    }
    
    func updateCodeUrl(conversation: ConversationResponse) {
        MixinDatabase.shared.update(maps: [(Conversation.Properties.codeUrl, conversation.codeUrl)], tableName: Conversation.tableName, condition: Conversation.Properties.conversationId == conversation.conversationId)
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: ConversationChange(conversationId: conversation.conversationId, action: .updateConversation(conversation: conversation)))
    }

    func getConversationIconUrl(conversationId: String) -> String? {
        return MixinDatabase.shared.scalar(on: Conversation.Properties.iconUrl, fromTable: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)?.stringValue
    }

    func updateIconUrl(conversationId: String, iconUrl: String) {
        MixinDatabase.shared.update(maps: [(Conversation.Properties.iconUrl, iconUrl)], tableName: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)
    }
    
    func getStartStatusConversations() -> [String] {
        return MixinDatabase.shared.getStringValues(column: Conversation.Properties.conversationId, tableName: Conversation.tableName, condition: Conversation.Properties.status == ConversationStatus.START.rawValue)
    }

    func getProblemConversations() -> [String] {
        return MixinDatabase.shared.getStringValues(column: Conversation.Properties.conversationId, tableName: Conversation.tableName, condition: Conversation.Properties.category == ConversationCategory.GROUP.rawValue && Conversation.Properties.status == ConversationStatus.SUCCESS.rawValue && Conversation.Properties.codeUrl.isNull())
    }

    func getQuitStatusConversations() -> [String] {
        return MixinDatabase.shared.getStringValues(column: Conversation.Properties.conversationId, tableName: Conversation.tableName, condition: Conversation.Properties.status == ConversationStatus.QUIT.rawValue)
    }

    func makeQuitConversation(conversationId: String) {
        MixinDatabase.shared.update(maps: [(Conversation.Properties.status, ConversationStatus.QUIT.rawValue)], tableName: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)
        ConcurrentJobQueue.shared.addJob(job: ExitConversationJob(conversationId: conversationId))
    }

    func updateConversationOwnerId(conversationId: String, ownerId: String) -> Bool {
        return MixinDatabase.shared.update(maps: [(Conversation.Properties.ownerId, ownerId)], tableName: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)
    }

    func updateConversationMuteUntil(conversationId: String, muteUntil: String) {
        MixinDatabase.shared.update(maps: [(Conversation.Properties.muteUntil, muteUntil)], tableName: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)
        guard let conversation = getConversation(conversationId: conversationId) else {
            return
        }
        let change = ConversationChange(conversationId: conversationId, action: .update(conversation: conversation))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }
    
    func updateConversationPinTime(conversationId: String, pinTime: String?) {
        MixinDatabase.shared.update(maps: [(Conversation.Properties.pinTime, pinTime ?? MixinDatabase.NullValue())], tableName: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)
    }
    
    func deleteConversationAndMessages(conversationId: String) {
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: Conversation.tableName, where: Conversation.Properties.conversationId == conversationId)
            try db.delete(fromTable: Message.tableName, where: Message.Properties.conversationId == conversationId)
        }
    }
    
    func deleteAndExitConversation(conversationId: String, autoNotification: Bool = true) {
        MessageDAO.shared.clearChat(conversationId: conversationId, autoNotification: false)
        AttachmentContainer.cleanUpAll()
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: Conversation.tableName, where: Conversation.Properties.conversationId == conversationId)
            try db.delete(fromTable: Participant.tableName, where: Participant.Properties.conversationId == conversationId)
            try db.delete(fromTable: ParticipantSession.tableName, where: ParticipantSession.Properties.conversationId == conversationId)
        }
        if autoNotification {
            NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: nil)
        }
    }

    func getConversation(ownerUserId: String) -> ConversationItem? {
        return MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQueryConversationByOwnerId, values: [ownerUserId]).first
    }

    func getConversation(conversationId: String) -> ConversationItem? {
        guard !conversationId.isEmpty else {
            return nil
        }
        return MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQueryConversationByCoversationId, values: [conversationId]).first
    }
    
    func getGroupOrStrangerConversation(withNameLike keyword: String, limit: Int?) -> [ConversationItem] {
        var sql = ConversationDAO.sqlQueryGroupOrStrangerConversationByName
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        let keyword = "%\(keyword.sqlEscaped)%"
        return MixinDatabase.shared.getCodables(sql: sql, values: [keyword, keyword])
    }
    
    func getConversation(withMessageLike keyword: String, limit: Int?, callback: (CoreStatement) -> Void) -> [MessagesWithinConversationSearchResult] {
        var sql = ConversationDAO.sqlSearchMessages
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        let keyword = "%\(keyword.sqlEscaped)%"
        let stmt = StatementSelectSQL(sql: sql)
        var items = [MessagesWithinConversationSearchResult]()
        let cs = try! MixinDatabase.shared.database.prepare(stmt)
        callback(cs)
        cs.bind(keyword, toIndex: 0)
        cs.bind(keyword, toIndex: 1)
        while (try? cs.step()) ?? false {
            var i = -1
            var autoIncrement: Int {
                i += 1
                return i
            }
            let conversationId: String = cs.value(atIndex: autoIncrement) ?? ""
            let categoryString: String = cs.value(atIndex: autoIncrement) ?? ""
            guard let category = ConversationCategory(rawValue: categoryString) else {
                continue
            }
            let name = cs.value(atIndex: autoIncrement) ?? ""
            let iconUrl = cs.value(atIndex: autoIncrement) ?? ""
            let userId = cs.value(atIndex: autoIncrement) ?? ""
            let userIsVerified = cs.value(atIndex: autoIncrement) ?? false
            let userAppId: String? = cs.value(atIndex: autoIncrement)
            let relatedMessageCount = cs.value(atIndex: autoIncrement) ?? 0
            let item: MessagesWithinConversationSearchResult
            switch category {
            case .CONTACT:
                item = MessagesWithUserSearchResult(conversationId: conversationId,
                                                    name: name,
                                                    iconUrl: iconUrl,
                                                    userId: userId,
                                                    userIsVerified: userIsVerified,
                                                    userAppId: userAppId,
                                                    relatedMessageCount: relatedMessageCount,
                                                    keyword: keyword)
            case .GROUP:
                item = MessagesWithGroupSearchResult(conversationId: conversationId,
                                                     name: name,
                                                     iconUrl: iconUrl,
                                                     relatedMessageCount: relatedMessageCount,
                                                     keyword: keyword)
            }
            items.append(item)
        }
        return items
    }

    func getOriginalConversation(conversationId: String) -> Conversation? {
        return MixinDatabase.shared.getCodable(condition: Conversation.Properties.conversationId == conversationId)
    }

    func getConversationStatus(conversationId: String) -> Int? {
        guard let result = MixinDatabase.shared.scalar(on: Conversation.Properties.status, fromTable: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)?.int32Value else {
            return nil
        }
        return Int(result)
    }

    func getConversationCategory(conversationId: String) -> String? {
        return MixinDatabase.shared.scalar(on: Conversation.Properties.category, fromTable: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)?.stringValue
    }
    
    func conversationList(limit: Int? = nil) -> [ConversationItem] {
        var sql = ConversationDAO.sqlQueryConversationList
        if let limit = limit {
            sql = sql + " LIMIT \(limit)"
        }
        return MixinDatabase.shared.getCodables(sql: sql)
    }

    func createPlaceConversation(conversationId: String, ownerId: String) {
        guard !conversationId.isEmpty else {
            return
        }
        guard !MixinDatabase.shared.isExist(type: Conversation.self, condition: Conversation.Properties.conversationId == conversationId) else {
            return
        }
        let conversation = Conversation.createConversation(conversationId: conversationId, category: nil, recipientId: ownerId, status: ConversationStatus.START.rawValue)
        MixinDatabase.shared.insert(objects: [conversation])
    }

    func createConversation(conversationId: String, name: String, members: [GroupUser]) -> Bool {
        let createdAt = Date().toUTCString()
        let conversation = Conversation(conversationId: conversationId, ownerId: AccountAPI.shared.accountUserId, category: ConversationCategory.GROUP.rawValue, name: name, iconUrl: nil, announcement: nil, lastMessageId: nil, lastMessageCreatedAt: createdAt, lastReadMessageId: nil, unseenMessageCount: 0, status: ConversationStatus.START.rawValue, draft: nil, muteUntil: nil, codeUrl: nil, pinTime: nil)
        var participants = members.map { Participant(conversationId: conversationId, userId: $0.userId, role: "", status: ParticipantStatus.SUCCESS.rawValue, createdAt: createdAt) }
        participants.append(Participant(conversationId: conversationId, userId: AccountAPI.shared.accountUserId, role: ParticipantRole.OWNER.rawValue, status: ParticipantStatus.SUCCESS.rawValue, createdAt: createdAt))

        return MixinDatabase.shared.transaction { (db) in
            try db.insert(objects: conversation, intoTable: Conversation.tableName)
            try db.insertOrReplace(objects: participants, intoTable: Participant.tableName)
        }
    }

    func createNewConversation(response: ConversationResponse) -> (ConversationItem, [ParticipantUser]) {
        let conversationId = response.conversationId
        var conversation: ConversationItem!
        var participantUsers = [ParticipantUser]()

        MixinDatabase.shared.transaction { (db) in
            try db.insert(objects: Conversation.createConversation(from: response, ownerId: AccountAPI.shared.accountUserId, status: .SUCCESS), intoTable: Conversation.tableName)

            let participants = response.participants.map { Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.SUCCESS.rawValue, createdAt: $0.createdAt) }
            try db.insert(objects: participants, intoTable: Participant.tableName)

            conversation = try db.prepareSelectSQL(on: ConversationItem.Properties.all, sql: ConversationDAO.sqlQueryConversationByCoversationId, values: [conversationId]).allObjects().first
            participantUsers = try db.prepareSelectSQL(on: ParticipantUser.Properties.all, sql: ParticipantDAO.sqlQueryGroupIconParticipants, values: [conversationId]).allObjects()
        }

        return (conversation, participantUsers)
    }

    @discardableResult
    func createConversation(conversation: ConversationResponse, targetStatus: ConversationStatus) -> Bool {
        var ownerId = conversation.creatorId
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            if let ownerParticipant = conversation.participants.first(where: { (participant) -> Bool in
                return participant.userId != AccountAPI.shared.accountUserId
            }) {
                ownerId = ownerParticipant.userId
            }
        }
        
        let conversationId = conversation.conversationId
        let oldStatus = ConversationDAO.shared.getConversationStatus(conversationId: conversation.conversationId)
        guard oldStatus == nil || oldStatus! != targetStatus.rawValue else {
            return true
        }

        return MixinDatabase.shared.transaction { (db) in
            if oldStatus == nil {
                let targetConversation = Conversation.createConversation(from: conversation, ownerId: ownerId, status: targetStatus)
                try db.insert(objects: targetConversation, intoTable: Conversation.tableName)
            } else {
                try db.update(table: Conversation.tableName, on: [Conversation.Properties.ownerId, Conversation.Properties.category, Conversation.Properties.name, Conversation.Properties.announcement, Conversation.Properties.status, Conversation.Properties.muteUntil, Conversation.Properties.codeUrl], with: [ownerId, conversation.category, conversation.name, conversation.announcement, targetStatus.rawValue, conversation.muteUntil, conversation.codeUrl], where: Conversation.Properties.conversationId == conversationId)
            }

            if conversation.participants.count > 0 {
                let participants = conversation.participants.map { Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.START.rawValue, createdAt: $0.createdAt) }
                try db.insertOrReplace(objects: participants, intoTable: Participant.tableName)

                if conversation.category == ConversationCategory.GROUP.rawValue {
                    let creatorId = conversation.creatorId
                    if !conversation.participants.contains(where: { $0.userId == creatorId }) {
                        ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [creatorId]))
                    }
                }
            }

            if let participantSessions = conversation.participantSessions, participantSessions.count > 0 {
                let sessionParticipants = participantSessions.map {
                    ParticipantSession(conversationId: conversationId, userId: $0.userId, sessionId: $0.sessionId, sentToServer: nil, createdAt: Date().toUTCString())
                }
                try db.insertOrReplace(objects: sessionParticipants, intoTable: ParticipantSession.tableName)
            }
            
            let statment = try db.prepareUpdateSQL(sql: ParticipantDAO.sqlUpdateStatus)
            try statment.execute(with: [conversationId])
            
            let userIds = try ParticipantDAO.shared.getNeedSyncParticipantIds(database: db, conversationId: conversationId)
            if userIds.count > 0 {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: userIds))
            }

            NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: ConversationChange(conversationId: conversationId, action: .updateConversation(conversation: conversation)))
        }
    }

    func updateConversation(conversation: ConversationResponse) {
        let conversationId = conversation.conversationId
        var ownerId = conversation.creatorId
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            if let ownerParticipant = conversation.participants.first(where: { (participant) -> Bool in
                return participant.userId != AccountAPI.shared.accountUserId
            }) {
                ownerId = ownerParticipant.userId
            }
        }
        guard let oldConversation: Conversation = MixinDatabase.shared.getCodable(condition: Conversation.Properties.conversationId == conversationId) else {
            return
        }

        if oldConversation.announcement != conversation.announcement, !conversation.announcement.isEmpty {
            AppGroupUserDefaults.User.hasUnreadAnnouncement[conversationId] = true
        }

        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: Participant.tableName, where: Participant.Properties.conversationId == conversationId)
            let participants = conversation.participants.map { Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.START.rawValue, createdAt: $0.createdAt) }
            try db.insertOrReplace(objects: participants, intoTable: Participant.tableName)

            try ParticipantSessionDAO.shared.syncConversationParticipantSession(conversation: conversation, db: db)

            let statment = try db.prepareUpdateSQL(sql: ParticipantDAO.sqlUpdateStatus)
            try statment.execute(with: [conversationId])

            try db.update(table: Conversation.tableName, on: [Conversation.Properties.ownerId, Conversation.Properties.category, Conversation.Properties.name, Conversation.Properties.announcement, Conversation.Properties.status, Conversation.Properties.muteUntil, Conversation.Properties.codeUrl], with: [ownerId, conversation.category, conversation.name, conversation.announcement, ConversationStatus.SUCCESS.rawValue, conversation.muteUntil, conversation.codeUrl], where: Conversation.Properties.conversationId == conversationId)

            let userIds = try ParticipantDAO.shared.getNeedSyncParticipantIds(database: db, conversationId: conversationId)
            if userIds.count > 0 {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: userIds))
            }

            NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: ConversationChange(conversationId: conversationId, action: .updateConversation(conversation: conversation)))
        }
    }

    func makeConversationId(userId: String, ownerUserId: String) -> String {
        return (min(userId, ownerUserId) + max(userId, ownerUserId)).toUUID()
    }

}
