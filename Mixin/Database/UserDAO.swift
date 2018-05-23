import WCDBSwift

final class UserDAO {

    static let shared = UserDAO()

    private static let sqlQueryColumns = """
    SELECT u.user_id, u.full_name, u.identity_number, u.avatar_url, u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at, a.description as appDescription, a.creator_id as appCreatorId
    FROM users u
    LEFT JOIN apps a ON a.app_id = u.app_id
    """

    private static let sqlQueryContacts = "\(sqlQueryColumns) WHERE u.relationship = 'FRIEND' ORDER BY u.created_at DESC"
    private static let sqlQueryUserByNameOrIdentityNumber = "\(sqlQueryColumns) WHERE u.relationship = 'FRIEND' AND u.full_name LIKE ? OR u.identity_number LIKE ?"
    private static let sqlQueryUserById = "\(sqlQueryColumns) WHERE u.user_id = ?"
    private static let sqlQueryUserByIdentityNumber = "\(sqlQueryColumns) WHERE u.identity_number = ?"
    private static let sqlQueryBlockedUsers = "\(sqlQueryColumns) WHERE relationship = 'BLOCKING'"

    func deleteUser(userId: String) {
        MixinDatabase.shared.delete(table: User.tableName, condition: User.Properties.userId == userId)
    }

    func getForwardContacts() -> [ForwardUser] {
        return MixinDatabase.shared.getCodables { (db) -> [ForwardUser] in
            let rows = try db.getRows(on: [User.Properties.userId, User.Properties.fullName, User.Properties.identityNumber, User.Properties.avatarUrl, User.Properties.isVerified, User.Properties.appId], fromTable: User.tableName, where: User.Properties.relationship == Relationship.FRIEND.rawValue, orderBy: [User.Properties.createdAt.asOrder(by: .descending)])
            var conversations = [ForwardUser]()
            for row in rows {
                let userId = row[0].stringValue
                let fullName = row[1].stringValue
                let identityNumber = row[2].stringValue
                let avatarUrl = row[3].stringValue
                let isVerified = row[4].int32Value == 1
                let appId = row[5].stringValue
                conversations.append(ForwardUser(name: "", iconUrl: "", userId: userId, identityNumber: identityNumber, fullName: fullName, ownerAvatarUrl: avatarUrl, ownerAppId: appId, ownerIsVerified: isVerified, category: "", conversationId: ""))
            }
            return conversations
        }
    }

    func insertSystemUser(userId: String) {
        guard !isExist(userId: userId) else {
            return
        }
        MixinDatabase.shared.insertOrReplace(objects: [User.createSystemUser()])
    }

    func isExist(userId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: User.self, condition: User.Properties.userId == userId)
    }

    func getBlockUsers() -> [UserItem] {
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryBlockedUsers, inTransaction: false)
    }

    func getUser(userId: String) -> UserItem? {
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryUserById, values: [userId], inTransaction: false).first
    }

    func getUser(identityNumber: String) -> UserItem? {
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryUserByIdentityNumber, values: [identityNumber], inTransaction: false).first
    }

    func getUsers(nameOrPhone keyword: String) -> [UserItem] {
        guard !keyword.isEmpty else {
            return []
        }
        let replacement = "%\(keyword)%"
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryUserByNameOrIdentityNumber, values: [replacement, replacement], inTransaction: false)
    }

    func contacts() -> [UserItem] {
        return MixinDatabase.shared.getCodables(sql: UserDAO.sqlQueryContacts, inTransaction: false)
    }

    func updateAccount(account: Account) {
        MixinDatabase.shared.insertOrReplace(objects: [User.createUser(from: account)])
    }

    func updateUsers(users: [UserResponse], sendNotificationAfterFinished: Bool = true, updateParticipantStatus: Bool = false, notifyContact: Bool = false) {
        guard users.count > 0 else {
            return
        }
        if Thread.isMainThread {
            DispatchQueue.global().async {
                UserDAO.shared.updateUsers(users: users, sendNotificationAfterFinished: sendNotificationAfterFinished, updateParticipantStatus: updateParticipantStatus, notifyContact: notifyContact)
            }
        } else {
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
            if notifyContact {
                NotificationCenter.default.afterPostOnMain(name: .ContactsDidChange)
            }
        }

    }

    func updateNotificationEnabled(userId: String, muteUntil: String) {
        DispatchQueue.global().async { [weak self] in
            MixinDatabase.shared.update(maps: [(User.Properties.muteUntil, muteUntil)], tableName: User.tableName, condition: User.Properties.userId == userId)
            if let user = self?.getUser(userId: userId) {
                NotificationCenter.default.afterPostOnMain(name: NSNotification.Name.UserDidChange, object: user)
            }
        }
    }
    
}

