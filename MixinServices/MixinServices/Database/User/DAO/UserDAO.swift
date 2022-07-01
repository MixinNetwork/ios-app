import GRDB

public final class UserDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let users = "users"
        public static let app = "app"
    }
    
    public static let shared = UserDAO()
    
    public static let usersDidChangeNotification = NSNotification.Name("one.mixin.services.UserDAO.usersDidChange")
    public static let correspondingAppDidChange = NSNotification.Name("one.mixin.services.UserDAO.correspondingAppDidChange")
    
    private static let sqlQueryColumns = """
    SELECT u.user_id, u.full_name, u.biography, u.identity_number, u.avatar_url, u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at, u.is_scam, '' AS role, a.creator_id as appCreatorId
    FROM users u
    LEFT JOIN apps a ON a.app_id = u.app_id
    """
    
    public func deleteUser(userId: String) {
        db.delete(User.self, where: User.column(of: .userId) == userId)
    }
    
    public func insertSystemUser(userId: String) {
        guard !isExist(userId: userId) else {
            return
        }
        let user = User.createSystemUser()
        db.save(user)
    }
    
    public func isExist(userId: String) -> Bool {
        db.recordExists(in: User.self, where: User.column(of: .userId) == userId)
    }
    
    public func getBlockUsers() -> [UserItem] {
        let sql = "\(Self.sqlQueryColumns) WHERE relationship = 'BLOCKING'"
        return db.select(with: sql)
    }
    
    public func getUser(userId: String) -> UserItem? {
        let sql = "\(Self.sqlQueryColumns) WHERE u.user_id = ?"
        return db.select(with: sql, arguments: [userId])
    }
    
    public func getUser(identityNumber: String) -> UserItem? {
        let sql = "\(Self.sqlQueryColumns) WHERE u.identity_number = ?"
        return db.select(with: sql, arguments: [identityNumber])
    }
    
    public func getUsers(keyword: String, limit: Int?) -> [UserItem] {
        var sql = """
        \(Self.sqlQueryColumns)
        WHERE u.relationship = 'FRIEND'
            AND u.identity_number > '0'
            AND ((u.full_name LIKE :escaped ESCAPE '/') OR (u.identity_number LIKE :escaped ESCAPE '/') OR (u.phone LIKE :escaped ESCAPE '/'))
        ORDER BY u.identity_number = :raw COLLATE NOCASE OR u.full_name = :raw COLLATE NOCASE DESC
        """
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        return db.select(with: sql, arguments: ["escaped": "%\(keyword.sqlEscaped)%", "raw": keyword])
    }
    
    public func getFriendUser(withAppId id: String) -> User? {
        let condition: SQLSpecificExpressible = User.column(of: .appId) == id
            && User.column(of: .relationship) == Relationship.FRIEND.rawValue
        return db.select(where: condition)
    }
    
    public func getUsers(with ids: [String]) -> [UserItem] {
        guard !ids.isEmpty else {
            return []
        }
        let wildcards = [String](repeating: "?", count: ids.count).joined(separator: ",")
        let sql = "\(UserDAO.sqlQueryColumns) WHERE u.user_id in (\(wildcards))"
        let users: [UserItem] = db.select(with: sql, arguments: StatementArguments(ids))
        let pairs = zip(users.map(\.userId), users)
        let map = [String: UserItem](uniqueKeysWithValues: pairs)
        return ids.compactMap { map[$0] }
    }
    
    public func getUsers(ofAppIds ids: [String]) -> [UserItem] {
        guard ids.count > 0 else {
            return []
        }
        let keys = ids.map { _ in "?" }.joined(separator: ",")
        let sql = "\(UserDAO.sqlQueryColumns) WHERE u.app_id in (\(keys))"
        let users: [UserItem] = db.select(with: sql, arguments: StatementArguments(ids))
        var userMap = [String: UserItem]()
        users.forEach { (user) in
            userMap[user.userId] = user
        }
        return ids.compactMap { userMap[$0] }
    }
    
    public func getUsers(withAppIds ids: [String]) -> [User] {
        guard ids.count > 0 else {
            return []
        }
        let keys = ids.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT u.*
            FROM apps a, users u
            WHERE u.app_id in (\(keys)) AND a.app_id = u.app_id AND u.relationship = 'FRIEND'
        """
        let users: [User] = db.select(with: sql, arguments: StatementArguments(ids))
        let userMap = users.reduce(into: [String: User]()) { $0[$1.userId] = $1 }
        return ids.compactMap { userMap[$0] }
    }
    
    public func getAppUsers(inConversationOf conversationId: String) -> [User] {
        let sql = """
        SELECT u.user_id, u.full_name, u.biography, u.identity_number, u.avatar_url,
                u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at, u.is_scam
        FROM participants p, apps a, users u
        WHERE p.conversation_id = ? AND p.user_id = u.user_id AND a.app_id = u.app_id
        """
        return db.select(with: sql, arguments: [conversationId])
    }
    
    public func getAppUsersAppId() -> [String] {
        let sql = """
            SELECT u.app_id
            FROM apps a, users u
            WHERE a.app_id = u.app_id AND u.relationship = 'FRIEND'
            ORDER BY u.full_name ASC
        """
        return db.select(with: sql)
    }
    
    public func getAppUsers() -> [User] {
        let sql = """
            SELECT u.user_id, u.full_name, u.biography, u.identity_number, u.avatar_url, u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at, u.is_scam
            FROM apps a, users u
            WHERE a.app_id = u.app_id AND u.relationship = 'FRIEND'
            ORDER BY u.full_name ASC
        """
        return db.select(with: sql)
    }
    
    public func getSearchableAppUsers(priorAppIds: [String]) -> [User] {
        var sql = """
            SELECT u.*
            FROM apps a, users u
            WHERE a.app_id = u.app_id AND u.relationship = 'FRIEND'
        """
        if !priorAppIds.isEmpty {
            let ids = priorAppIds.joined(separator: "','")
            sql += "\nORDER BY a.app_id IN ('\(ids)') DESC"
        }
        sql += "\nLIMIT 1000"
        return db.select(with: sql)
    }
    
    public func getSearchableAppUsers(with appIds: [String]) -> [User] {
        guard !appIds.isEmpty else {
            return []
        }
        let ids = appIds.joined(separator: "','")
        let sql = """
            SELECT u.*
            FROM apps a, users u
            WHERE a.app_id IN ('\(ids)') AND a.app_id = u.app_id AND u.relationship = 'FRIEND'
        """
        return db.select(with: sql)
    }
    
    public func getFullname(userId: String) -> String? {
        db.select(column: User.column(of: .fullName),
                  from: User.self,
                  where: User.column(of: .userId) == userId)
    }
    
    public func appFriends(notIn ids: [String]) -> [User] {
        let condition = User.column(of: .relationship) == Relationship.FRIEND.rawValue
            && User.column(of: .appId) != nil
            && !ids.contains(User.column(of: .appId))
        return db.select(where: condition)
    }
    
    public func botGroupUsers(conversationId: String, keyword: String, createAt: String) -> [UserItem] {
        let sql = """
        SELECT u.*
        FROM users u
        WHERE (u.user_id in (SELECT m.user_id FROM messages m WHERE conversation_id = :cid AND m.created_at > :cat)
        OR u.user_id in (SELECT f.user_id FROM users f WHERE relationship = 'FRIEND'))
        AND u.user_id != :uid
        AND (u.full_name LIKE '%' || :keyword || '%' ESCAPE '/' OR u.identity_number like '%' || :keyword || '%' ESCAPE '/')
        ORDER BY CASE u.relationship WHEN 'FRIEND' THEN 1 ELSE 2 END,
        u.relationship OR u.full_name = :keyword COLLATE NOCASE OR u.identity_number = :keyword COLLATE NOCASE DESC
        """
        let arguments = ["cid": conversationId,
                         "cat": createAt,
                         "uid": myUserId,
                         "keyword": keyword]
        return db.select(with: sql, arguments: StatementArguments(arguments))
    }
    
    public func contacts(count: Int) -> [UserItem] {
        let sql = "\(Self.sqlQueryColumns) WHERE u.relationship = 'FRIEND' AND u.identity_number > '0' ORDER BY u.created_at DESC LIMIT ?"
        return db.select(with: sql, arguments: [count])
    }
    
    public func contacts() -> [UserItem] {
        let sql = "\(Self.sqlQueryColumns) WHERE u.relationship = 'FRIEND' AND u.identity_number > '0' ORDER BY u.created_at DESC"
        return db.select(with: sql)
    }
    
    public func contactsWithoutApp() -> [UserItem] {
        let sql = "\(Self.sqlQueryColumns) WHERE u.app_id IS NULL AND u.relationship = 'FRIEND' AND u.identity_number > '0' ORDER BY u.created_at DESC"
        return db.select(with: sql)
    }
    
    public func mentionRepresentation(identityNumbers: [String]) -> [String: String] {
        db.select(keyColumn: User.column(of: .identityNumber),
                  valueColumn: User.column(of: .fullName),
                  from: User.self,
                  where: identityNumbers.contains(User.column(of: .identityNumber)))
    }
    
    public func userIds(identityNumbers: [String]) -> [String] {
        db.select(column: User.column(of: .userId),
                  from: User.self,
                  where: identityNumbers.contains(User.column(of: .identityNumber)))
    }
    
    public func updateAccount(account: Account) {
        let user = User.createUser(from: account)
        db.save(user)
    }
    
    public func updateUsers(users: [UserResponse], updateParticipantStatus: Bool = false) {
        guard users.count > 0 else {
            return
        }
        if Thread.isMainThread {
            DispatchQueue.global().async {
                UserDAO.shared.updateUsers(users: users, updateParticipantStatus: updateParticipantStatus)
            }
        } else {
            let isAppUpdated: Bool
            if users.count == 1, let newApp = users[0].app {
                isAppUpdated = AppDAO.shared.getApp(appId: newApp.appId)?.updatedAt != newApp.updatedAt
            } else {
                isAppUpdated = false
            }
            db.write { (db) in
                for response in users {
                    let user = User.createUser(from: response)
                    try user.save(db)
                    if let app = user.app {
                        try app.save(db)
                    }
                    if updateParticipantStatus {
                        try Participant
                            .filter(Participant.column(of: .userId) == user.userId)
                            .updateAll(db, [Participant.column(of: .status).set(to: ParticipantStatus.SUCCESS.rawValue)])
                    }
                }
                db.afterNextTransactionCommit { (_) in
                    NotificationCenter.default.post(onMainThread: Self.usersDidChangeNotification,
                                                    object: self,
                                                    userInfo: [Self.UserInfoKey.users: users])
                    if isAppUpdated {
                        NotificationCenter.default.post(onMainThread: Self.correspondingAppDidChange,
                                                        object: self,
                                                        userInfo: [Self.UserInfoKey.app: users[0].app])
                    }
                }
            }
        }
    }
    
    public func updateUser(with userId: String, muteUntil: String) {
        db.update(User.self,
                  assignments: [User.column(of: .muteUntil).set(to: muteUntil)],
                  where: User.column(of: .userId) == userId)
    }
    
    public func saveUser(user response: UserResponse) -> UserItem? {
        var userItem: UserItem?
        db.write { (db) in
            let user = User.createUser(from: response)
            try user.save(db)
            if let app = user.app {
                try app.save(db)
            }
            db.afterNextTransactionCommit { (_) in
                userItem = self.getUser(userId: user.userId)
            }
        }
        return userItem
    }
    
}
