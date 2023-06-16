import UIKit
import GRDB

public final class ExpiredMessageDAO: UserDatabaseDAO {
    
    public static let messageIdKey = "mid"

    public static let expiredAtDidUpdateNotification = Notification.Name("one.mixin.services.ExpiredMessageDAO.expiredAtDidUpdate")
    public static let expiredMessageDidDeleteNotification = Notification.Name("one.mixin.services.ExpiredMessageDAO.expiredMessageDidDelete")

    public static let shared = ExpiredMessageDAO()
    
    public func insert(message: ExpiredMessage, conversationId: String? = nil) {
        db.write { db in
            try insert(message: message, conversationId: conversationId, database: db)
        }
    }
    
    public func insert(message: ExpiredMessage, conversationId: String? = nil, database: GRDB.Database) throws {
        try message.save(database)
        if message.expireAt != nil || conversationId != nil {
            database.afterNextTransaction { _ in
                if message.expireAt != nil {
                    NotificationCenter.default.post(onMainThread: Self.expiredAtDidUpdateNotification, object: self)
                }
                if let conversationId = conversationId {
                    let change = ConversationChange(conversationId: conversationId,
                                                    action: .updateExpireIn(expireIn: message.expireIn, messageId: message.messageId))
                    NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: change)
                }
            }
        }
    }
    
    // In argument messages, key is message id, value is expire_at
    public func updateExpireAt(for messages: [String: Int64]) {
        db.write { db in
            for message in messages {
                try updateExpireAt(for: message.key, database: db, expireAt: message.value, postNotification: false)
            }
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(onMainThread: Self.expiredAtDidUpdateNotification, object: self)
            }
        }
    }
    
    public func updateExpireAt(for messageId: String, database: GRDB.Database, expireAt: Int64? = nil, postNotification: Bool) throws {
        let condition: SQLSpecificExpressible = ExpiredMessage.column(of: .messageId) == messageId
            && ExpiredMessage.column(of: .expireAt) == nil
        guard let message = try ExpiredMessage.filter(condition).fetchOne(database) else {
            return
        }
        let expireAt = expireAt ?? Int64(Date().addingTimeInterval(TimeInterval(message.expireIn)).timeIntervalSince1970)
        try ExpiredMessage
            .filter(ExpiredMessage.column(of: .messageId) == messageId)
            .updateAll(database, [ExpiredMessage.column(of: .expireAt).set(to: expireAt)])
        if postNotification {
            database.afterNextTransaction { _ in
                NotificationCenter.default.post(onMainThread: Self.expiredAtDidUpdateNotification, object: self)
            }
        }
    }
    
    public func updateExpireAts(expireAts: [String: Int64], database: GRDB.Database) throws {
        guard !expireAts.isEmpty else {
            return
        }
        var hasUpdated = false
        for (messageId, expireAt) in expireAts {
            let updateCount = try ExpiredMessage
                .filter(ExpiredMessage.column(of: .messageId) == messageId)
                .updateAll(database, [ExpiredMessage.column(of: .expireAt).set(to: expireAt)])
            hasUpdated = hasUpdated || updateCount > 0
        }
        if hasUpdated {
            database.afterNextTransaction { _ in
                NotificationCenter.default.post(onMainThread: Self.expiredAtDidUpdateNotification, object: self)
            }
        }
    }
    
    public func expireIn(for messageId: String) -> Int64? {
        db.select(column: ExpiredMessage.column(of: .expireIn),
                  from: ExpiredMessage.self,
                  where: ExpiredMessage.column(of: .messageId) == messageId)
    }
    
    public func removeExpiredMessages(reportNextExpireAt: @escaping (Int64?) -> Void) {
        db.write { db in
            let condition: SQLSpecificExpressible = ExpiredMessage.column(of: .expireAt) != nil
                && ExpiredMessage.column(of: .expireAt) <= Int64(Date().timeIntervalSince1970)
            let expiredMessageIds: [String] = try ExpiredMessage
                .select(ExpiredMessage.column(of: .messageId))
                .filter(condition)
                .limit(100)
                .fetchAll(db)
            
            var deletedMessages: [(message: MessageItem, transcriptChildrenIds: [String])] = []
            if !expiredMessageIds.isEmpty {
                var unseenCountChangedConversationIds: Set<String> = []
                let expiredMessages = try MessageDAO.shared.getFullMessages(messageIds: expiredMessageIds, with: db)
                for message in expiredMessages {
                    let (deleted, childMessageIds) = try MessageDAO.shared.deleteMessage(id: message.messageId, with: db)
                    if deleted {
                        deletedMessages.append((message, childMessageIds))
                        if message.status != MessageStatus.READ.rawValue {
                            unseenCountChangedConversationIds.insert(message.conversationId)
                        }
                    }
                }
                for id in unseenCountChangedConversationIds {
                    try MessageDAO.shared.updateUnseenMessageCount(database: db, conversationId: id)
                }
                try ExpiredMessage
                    .filter(expiredMessageIds.contains(ExpiredMessage.column(of: .messageId)))
                    .deleteAll(db)
            }
            
            let nextExpireAt: Int64? = try ExpiredMessage
                .select(ExpiredMessage.column(of: .expireAt))
                .filter(ExpiredMessage.column(of: .expireAt) != nil)
                .order([ExpiredMessage.column(of: .expireAt).asc])
                .fetchOne(db)
            db.afterNextTransaction { _ in
                Logger.general.info(category: "ExpiredMessageDAO", message: "Deleted \(deletedMessages.count) messages")
                DispatchQueue.global().async {
                    for (message, childrenIds) in deletedMessages {
                        ReceiveMessageService.shared.stopRecallMessage(item: message, childMessageIds: childrenIds)
                    }
                }
                DispatchQueue.main.async {
                    for (message, _) in deletedMessages {
                        NotificationCenter.default.post(name: Self.expiredMessageDidDeleteNotification,
                                                        object: nil,
                                                        userInfo: [Self.messageIdKey: message.messageId])
                    }
                    if !deletedMessages.isEmpty {
                        NotificationCenter.default.post(name: MixinServices.conversationDidChangeNotification, object: nil)
                    }
                    reportNextExpireAt(nextExpireAt)
                }
            }
        }
    }
    
    public func expiredMessages(limit: Int, after messageId: String?) -> [ExpiredMessage] {
        var sql = "SELECT * FROM expired_messages"
        if let messageId {
            sql += " WHERE ROWID > IFNULL((SELECT ROWID FROM expired_messages WHERE message_id = '\(messageId)'), 0)"
        }
        sql += " ORDER BY ROWID LIMIT ?"
        return db.select(with: sql, arguments: [limit])
    }
    
    public func expiredMessagesCount() -> Int64 {
        let count: Int64? = db.select(with: "SELECT COUNT(*) FROM expired_messages")
        return count ?? 0
    }
    
    public func save(expiredMessage: ExpiredMessage) {
        db.save(expiredMessage)
    }
    
}
