import WCDBSwift

public final class UserDAO {
    
    public static let shared = UserDAO()
    
    private static let sqlQueryColumns = """
    SELECT u.user_id, u.full_name, u.biography, u.identity_number, u.avatar_url, u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at, u.is_scam, a.creator_id as appCreatorId
    FROM users u
    LEFT JOIN apps a ON a.app_id = u.app_id
    """
    
    private static let sqlQueryUserById = "\(sqlQueryColumns) WHERE u.user_id = ?"
    private static let sqlQueryUserByIdentityNumber = "\(sqlQueryColumns) WHERE u.identity_number = ?"
    private static let sqlQueryUserByKeyword = "\(sqlQueryColumns) WHERE u.relationship = 'FRIEND' AND u.identity_number > '0' AND ((u.full_name LIKE ? ESCAPE '/') OR (u.identity_number LIKE ? ESCAPE '/') OR (u.phone LIKE ? ESCAPE '/'))"
    private static let sqlQueryBlockedUsers = "\(sqlQueryColumns) WHERE relationship = 'BLOCKING'"
    private static let sqlQueryAppUserInConversation = """
    SELECT u.user_id, u.full_name, u.biography, u.identity_number, u.avatar_url, u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at, u.is_scam
    FROM participants p, apps a, users u
    WHERE p.conversation_id = ? AND p.user_id = u.user_id AND a.app_id = u.app_id
    """
    
    public func deleteUser(userId: String) {
        MixinDatabase.shared.delete(table: User.tableName, condition: User.Properties.userId == userId)
    }
    
    public func insertSystemUser(userId: String) {
        guard !isExist(userId: userId) else {
            return
        }
        MixinDatabase.shared.insertOrReplace(objects: [User.createSystemUser()])
    }
    
    public func isExist(userId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: User.self, condition: User.Properties.userId == userId)
    }
    
    public func getBlockUsers() -> [UserItem] {
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryBlockedUsers)
    }
    
    public func getUser(userId: String) -> UserItem? {
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryUserById, values: [userId]).first
    }
    
    public func getUser(identityNumber: String) -> UserItem? {
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryUserByIdentityNumber, values: [identityNumber]).first
    }
    
    public func getUsers(keyword: String, limit: Int?) -> [UserItem] {
        let keyword = "%\(keyword.sqlEscaped)%"
        var sql = UserDAO.sqlQueryUserByKeyword
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        return MixinDatabase.shared.getCodables(sql: sql, values: [keyword, keyword, keyword])
    }
    
    public func getFriendUser(withAppId id: String) -> User? {
        let condition = User.Properties.appId == id
            && User.Properties.relationship == Relationship.FRIEND.rawValue
        return MixinDatabase.shared.getCodable(condition: condition)
    }
    
    public func getUsers(ofAppIds ids: [String]) -> [UserItem] {
        guard ids.count > 0 else {
            return []
        }
        let keys = ids.map { _ in "?" }.joined(separator: ",")
        let sql = "\(UserDAO.sqlQueryColumns) WHERE u.app_id in (\(keys))"
        let users: [UserItem] = MixinDatabase.shared.getCodables(sql: sql, values: ids)
        var userMap = [String: UserItem]()
        users.forEach { (user) in
            userMap[user.userId] = user
        }
        return ids.compactMap { userMap[$0] }
    }
    
    public func getAppUsers(inConversationOf conversationId: String) -> [User] {
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryAppUserInConversation, values: [conversationId])
    }
    
    public func getAppUsers() -> [User] {
        let sql = """
            SELECT u.user_id, u.full_name, u.biography, u.identity_number, u.avatar_url, u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at, u.is_scam
            FROM apps a, users u
            WHERE a.app_id = u.app_id AND u.relationship = 'FRIEND'
            ORDER BY u.full_name ASC
        """
        return MixinDatabase.shared.getCodables(sql: sql)
    }
    
    public func getFullname(userId: String) -> String? {
        let values = MixinDatabase.shared.getStringValues(column: User.Properties.fullName.asColumnResult(),
                                                          tableName: User.tableName,
                                                          condition: User.Properties.userId == userId,
                                                          orderBy: nil,
                                                          limit: 1)
        return values.first
    }
    
    public func appFriends(notIn ids: [String]) -> [User] {
        let condition = User.Properties.relationship == Relationship.FRIEND.rawValue
            && User.Properties.appId.isNotNull()
            && User.Properties.appId.notIn(ids)
        return MixinDatabase.shared.getCodables(condition: condition)
    }
    
    public func contacts() -> [UserItem] {
        let sql = "\(Self.sqlQueryColumns) WHERE u.relationship = 'FRIEND' AND u.identity_number > '0' ORDER BY u.created_at DESC"
        return MixinDatabase.shared.getCodables(sql: sql)
    }
    
    public func contactsWithoutApp() -> [UserItem] {
        let sql = "\(Self.sqlQueryColumns) WHERE u.app_id IS NULL AND u.relationship = 'FRIEND' AND u.identity_number > '0' ORDER BY u.created_at DESC"
        return MixinDatabase.shared.getCodables(sql: sql)
    }
    
    public func mentionRepresentation(identityNumbers: [String]) -> [String: String] {
        return MixinDatabase.shared.getDictionary(key: User.Properties.identityNumber.asColumnResult(), value: User.Properties.fullName.asColumnResult(), tableName: User.tableName, condition: User.Properties.identityNumber.in(identityNumbers))
    }

    public func userIds(identityNumbers: [String]) -> [String] {
        return MixinDatabase.shared.getStringValues(column: User.Properties.userId.asColumnResult(), tableName: User.tableName, condition: User.Properties.identityNumber.in(identityNumbers))
    }
    
    public func updateAccount(account: Account) {
        MixinDatabase.shared.insertOrReplace(objects: [User.createUser(from: account)])
    }
    
    public func updateUsers(users: [UserResponse], sendNotificationAfterFinished: Bool = true, updateParticipantStatus: Bool = false, notifyContact: Bool = false) {
        guard users.count > 0 else {
            return
        }
        if Thread.isMainThread {
            DispatchQueue.global().async {
                UserDAO.shared.updateUsers(users: users, sendNotificationAfterFinished: sendNotificationAfterFinished, updateParticipantStatus: updateParticipantStatus, notifyContact: notifyContact)
            }
        } else {
            var isAppUpdated = false
            if sendNotificationAfterFinished, users.count == 1, let newApp = users[0].app {
                isAppUpdated = AppDAO.shared.getApp(appId: newApp.appId)?.updatedAt != newApp.updatedAt
            }

            MixinDatabase.shared.transaction { (db) in
                for user in users {
                    try db.insertOrReplace(objects: User.createUser(from: user), intoTable: User.tableName)
                    if let app = user.app {
                        try db.insertOrReplace(objects: app, intoTable: App.tableName)
                    }
                    
                    if updateParticipantStatus {
                        try db.update(table: Participant.tableName, on: [Participant.Properties.status], with: [ParticipantStatus.SUCCESS.rawValue], where: Participant.Properties.userId == user.userId)
                    }
                }
            }
            if sendNotificationAfterFinished {
                if users.count == 1 {
                    NotificationCenter.default.afterPostOnMain(name: .UserDidChange, object: UserItem.createUser(from: users[0]))
                }
            }
            if isAppUpdated {
                NotificationCenter.default.afterPostOnMain(name: .AppDidChange, object: users[0].app?.appId)
            }
            if notifyContact {
                NotificationCenter.default.afterPostOnMain(name: .ContactsDidChange)
            }
        }
        
    }
    
    public func updateNotificationEnabled(userId: String, muteUntil: String) {
        DispatchQueue.global().async { [weak self] in
            MixinDatabase.shared.update(maps: [(User.Properties.muteUntil, muteUntil)], tableName: User.tableName, condition: User.Properties.userId == userId)
            if let user = self?.getUser(userId: userId) {
                NotificationCenter.default.afterPostOnMain(name: NSNotification.Name.UserDidChange, object: user)
            }
        }
    }
    
}
