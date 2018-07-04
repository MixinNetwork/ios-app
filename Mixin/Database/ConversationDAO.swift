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
    private static let sqlQuerySearchConversation = """
    \(sqlQueryColumns)
    FROM messages m
    LEFT JOIN conversations c ON m.conversation_id = c.conversation_id
    LEFT JOIN users u ON u.user_id = m.user_id
    INNER JOIN users u1 ON u1.user_id = c.owner_id
    LEFT JOIN users u2 ON u2.user_id = m.participant_id
    WHERE (m.category LIKE '%_TEXT' AND m.content LIKE ?) OR (m.category LIKE '%_DATA' AND m.name LIKE ?)
    ORDER BY c.pin_time DESC, m.created_at DESC
    """
    private static let sqlQueryConversationList = String(format: sqlQueryConversation, "")
    private static let sqlQueryConversationByOwnerId = String(format: sqlQueryConversation, " AND c.owner_id = ? AND c.category = 'CONTACT'")
    private static let sqlQueryConversationByCoversationId = String(format: sqlQueryConversation, " AND c.conversation_id = ? ")
    private static let sqlQueryConversationByName = String(format: sqlQueryConversation, "AND c.name LIKE ?") + " LIMIT 1"
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

    func getCategoryStorages(conversationId: String) -> [ConversationCategoryStorage] {
        return MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQueryConversationStorageUsage, values: [conversationId])
    }

    func storageUsageConversations() -> [ConversationStorageUsage] {
        return MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQueryStorageUsage)
    }

    func isExist(conversationId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Conversation.self, condition: Conversation.Properties.conversationId == conversationId)
    }

    func updateCodeUrl(conversation: ConversationResponse) {
        MixinDatabase.shared.update(maps: [(Conversation.Properties.codeUrl, conversation.codeUrl)], tableName: Conversation.tableName, condition: Conversation.Properties.conversationId == conversation.conversationId)
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: ConversationChange(conversationId: conversation.conversationId, action: .updateConversation(conversation: conversation)))
    }

    func getConversationIconUrl(conversationId: String) -> String? {
        return MixinDatabase.shared.scalar(on: Conversation.Properties.iconUrl, fromTable: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId, inTransaction: false)?.stringValue
    }

    func updateIconUrl(conversationId: String, iconUrl: String) {
        MixinDatabase.shared.update(maps: [(Conversation.Properties.iconUrl, iconUrl)], tableName: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId)
    }

    func getForwardConversations() -> [ForwardUser] {
        return MixinDatabase.shared.getCodables { (db) -> [ForwardUser] in
            let conversationIdColumn = Conversation.Properties.conversationId.in(table: Conversation.tableName)
            let nameColumn = Conversation.Properties.name.in(table: Conversation.tableName)
            let iconUrlColumn = Conversation.Properties.iconUrl.in(table: Conversation.tableName)
            let categoryColumn = Conversation.Properties.category.in(table: Conversation.tableName)
            let ownerUserIdColumn = Conversation.Properties.ownerId.in(table: Conversation.tableName)
            let lastMessageCreatedAtColumn = Conversation.Properties.lastMessageCreatedAt.in(table: Conversation.tableName)
            let pinTimeColumn = Conversation.Properties.pinTime.in(table: Conversation.tableName)
            let ownerIdentityNumberColumn = User.Properties.identityNumber.in(table: User.tableName)
            let ownerAvatarUrlColumn = User.Properties.avatarUrl.in(table: User.tableName)
            let ownerFullName = User.Properties.fullName.in(table: User.tableName)
            let ownerIsVerified = User.Properties.isVerified.in(table: User.tableName)
            let ownerAppId = User.Properties.appId.in(table: User.tableName)

            let columns = [conversationIdColumn, nameColumn, iconUrlColumn, categoryColumn, ownerUserIdColumn, ownerIdentityNumberColumn, ownerAvatarUrlColumn, ownerFullName, ownerIsVerified, ownerAppId]

            let userIdColumn = User.Properties.userId.in(table: User.tableName)
            let statusColumn = Conversation.Properties.status.in(table: Conversation.tableName)
            let joinClause = JoinClause(with: Conversation.tableName)
                .join(User.tableName, with: .left)
                .on(userIdColumn == ownerUserIdColumn)

            let statementSelect = StatementSelect().select(columns).from(joinClause).where(categoryColumn.isNotNull() && statusColumn != ConversationStatus.QUIT.rawValue).order(by: [pinTimeColumn.asOrder(by: .descending), lastMessageCreatedAtColumn.asOrder(by: .descending)])
            let coreStatement = try db.prepare(statementSelect)

            var conversations = [ForwardUser]()
            while try coreStatement.step() {
                let conversationId = coreStatement.value(atIndex: 0).stringValue
                let name = coreStatement.value(atIndex: 1).stringValue
                let iconUrl = coreStatement.value(atIndex: 2).stringValue
                let category = coreStatement.value(atIndex: 3).stringValue
                let userId = coreStatement.value(atIndex: 4).stringValue
                let identityNumber = coreStatement.value(atIndex: 5).stringValue
                let avatarUrl = coreStatement.value(atIndex: 6).stringValue
                let fullName = coreStatement.value(atIndex: 7).stringValue
                let isVerified = coreStatement.value(atIndex: 8).int32Value == 1
                let appId = coreStatement.value(atIndex: 9).stringValue
                conversations.append(ForwardUser(name: name, iconUrl: iconUrl, userId: userId, identityNumber: identityNumber, fullName: fullName, ownerAvatarUrl: avatarUrl, ownerAppId: appId, ownerIsVerified: isVerified, category: category, conversationId: conversationId))
            }
            return conversations
        }
    }

    func getStartStatusConversations() -> [String] {
        return MixinDatabase.shared.getStringValues(column: Conversation.Properties.conversationId, tableName: Conversation.tableName, condition: Conversation.Properties.status == ConversationStatus.START.rawValue, inTransaction: false)
    }

    func getProblemConversations() -> [String] {
        return MixinDatabase.shared.getStringValues(column: Conversation.Properties.conversationId, tableName: Conversation.tableName, condition: Conversation.Properties.category == ConversationCategory.GROUP.rawValue && Conversation.Properties.status == ConversationStatus.SUCCESS.rawValue && Conversation.Properties.codeUrl.isNull(), inTransaction: false)
    }

    func getQuitStatusConversations() -> [String] {
        return MixinDatabase.shared.getStringValues(column: Conversation.Properties.conversationId, tableName: Conversation.tableName, condition: Conversation.Properties.status == ConversationStatus.QUIT.rawValue, inTransaction: false)
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

    func deleteAndExitConversation(conversationId: String, autoNotification: Bool = true) {
        guard MixinDatabase.shared.delete(table: Conversation.tableName, condition: Conversation.Properties.conversationId == conversationId, cascadeDelete: true) > 0, autoNotification else {
            return
        }

        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: nil)
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

    func getOriginalConversation(conversationId: String) -> Conversation? {
        return MixinDatabase.shared.getCodable(condition: Conversation.Properties.conversationId == conversationId, inTransaction: false)
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

    func searchConversation(content: String) -> [ConversationItem] {
        guard !content.isEmpty else {
            return []
        }
        let keyword = "%\(content)%"

        let conversations: [ConversationItem] = MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQueryConversationByName, values: [keyword], inTransaction: false)
        let messages: [ConversationItem] = MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQuerySearchConversation, values: [keyword, keyword], inTransaction: false)
        return conversations + messages
    }

    func conversationList() -> [ConversationItem] {
        return MixinDatabase.shared.getCodables(sql: ConversationDAO.sqlQueryConversationList, inTransaction: false)
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
        return MixinDatabase.shared.transaction { (db) in
            let createdAt = Date().toUTCString()
            
            let conversation = Conversation(conversationId: conversationId, ownerId: AccountAPI.shared.accountUserId, category: ConversationCategory.GROUP.rawValue, name: name, iconUrl: nil, announcement: nil, lastMessageId: nil, lastMessageCreatedAt: createdAt, lastReadMessageId: nil, unseenMessageCount: 0, status: ConversationStatus.START.rawValue, draft: nil, muteUntil: nil, codeUrl: nil, pinTime: nil)
            try db.insert(objects: conversation, intoTable: Conversation.tableName)
            
            var participants = members.map { Participant(conversationId: conversationId, userId: $0.userId, role: "", status: ParticipantStatus.SUCCESS.rawValue, createdAt: createdAt) }
            participants.append(Participant(conversationId: conversationId, userId: AccountAPI.shared.accountUserId, role: ParticipantRole.OWNER.rawValue, status: ParticipantStatus.SUCCESS.rawValue, createdAt: createdAt))
            try db.insertOrReplace(objects: participants, intoTable: Participant.tableName)
        }
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
                var targetConversation = Conversation.createConversation(from: conversation)
                targetConversation.status = targetStatus.rawValue
                targetConversation.ownerId = ownerId
                try db.insert(objects: targetConversation, intoTable: Conversation.tableName)
            } else {
                try db.update(table: Conversation.tableName, on: [Conversation.Properties.ownerId, Conversation.Properties.category, Conversation.Properties.name, Conversation.Properties.announcement, Conversation.Properties.status, Conversation.Properties.muteUntil, Conversation.Properties.codeUrl], with: [ownerId, conversation.category, conversation.name, conversation.announcement, targetStatus.rawValue, conversation.muteUntil, conversation.codeUrl], where: Conversation.Properties.conversationId == conversationId)
            }

            if conversation.participants.count > 0 {
                let participants = conversation.participants.map { Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.START.rawValue, createdAt: $0.createdAt) }
                try db.insertOrReplace(objects: participants, intoTable: Participant.tableName)
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
        let participants = conversation.participants
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
        let oldUserIds = MixinDatabase.shared.getStringValues(column: Participant.Properties.userId, tableName: Participant.tableName, condition: Participant.Properties.conversationId == conversationId)
        let newUserIds: [String] = participants.flatMap({ (participant) -> String in
            return participant.userId
        })
        if oldConversation.announcement != conversation.announcement, !conversation.announcement.isEmpty {
            CommonUserDefault.shared.setHasUnreadAnnouncement(true, forConversationId: conversationId)
        }

        MixinDatabase.shared.transaction { (db) in
            for userId in oldUserIds {
                if !newUserIds.contains(userId) {
                    try db.delete(fromTable: Participant.tableName, where: Participant.Properties.conversationId == conversationId && Participant.Properties.userId == userId)
                }
            }

            let participants = conversation.participants.map { Participant(conversationId: conversationId, userId: $0.userId, role: $0.role, status: ParticipantStatus.START.rawValue, createdAt: $0.createdAt) }
            try db.insertOrReplace(objects: participants, intoTable: Participant.tableName)

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
