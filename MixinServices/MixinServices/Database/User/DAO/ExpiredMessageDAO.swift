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
            database.afterNextTransactionCommit { _ in
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
    
    public func updateExpireAt(for messageId: String, expireAt: Int64?) {
        db.write { db in
            try updateExpireAt(for: messageId, database: db, expireAt: expireAt)
        }
    }

    public func updateExpireAt(for messageId: String, database: GRDB.Database, expireAt: Int64? = nil) throws {
        let condition: SQLSpecificExpressible = ExpiredMessage.column(of: .messageId) == messageId
            && ExpiredMessage.column(of: .expireAt) == nil
        guard let message = try ExpiredMessage.filter(condition).fetchOne(database) else {
            return
        }
        let expireAt = expireAt ?? Int64(Date().addingTimeInterval(TimeInterval(message.expireIn)).timeIntervalSince1970)
        try ExpiredMessage
            .filter(ExpiredMessage.column(of: .messageId) == messageId)
            .updateAll(database, [ExpiredMessage.column(of: .expireAt).set(to: expireAt)])
        database.afterNextTransactionCommit { _ in
            NotificationCenter.default.post(onMainThread: Self.expiredAtDidUpdateNotification, object: self)
        }
    }
    
    public func updateExpireAts(expireIns: [String: Int64], database: GRDB.Database) throws {
        guard !expireIns.isEmpty else {
            return
        }
        var hasUpdated = false
        for (messageId, expireIn) in expireIns {
            let expireAt = Int64(Date().addingTimeInterval(TimeInterval(expireIn)).timeIntervalSince1970)
            let updateCount = try ExpiredMessage
                .filter(ExpiredMessage.column(of: .messageId) == messageId)
                .updateAll(database, [ExpiredMessage.column(of: .expireAt).set(to: expireAt)])
            hasUpdated = hasUpdated || updateCount > 0
        }
        if hasUpdated {
            database.afterNextTransactionCommit { _ in
                NotificationCenter.default.post(onMainThread: Self.expiredAtDidUpdateNotification, object: self)
            }
        }
    }
    
    public func removeExpiredMessages(completion: (_ nextExpireAt: Int64?) -> Void) {
        db.write { db in
            let condition: SQLSpecificExpressible = ExpiredMessage.column(of: .expireAt) != nil
                && ExpiredMessage.column(of: .expireAt) <= Int64(Date().timeIntervalSince1970)
            let expiredMessageIds: [String] = try ExpiredMessage
                .select(ExpiredMessage.column(of: .messageId))
                .filter(condition)
                .limit(100)
                .fetchAll(db)
            let expiredMessages = try MessageDAO.shared.getFullMessages(messageIds: expiredMessageIds)
            for id in expiredMessageIds {
                let (deleted, childMessageIds) = try MessageDAO.shared.deleteMessage(id: id, with: db)
                if deleted {
                    if let message = expiredMessages.first(where: { $0.messageId == id }) {
                        ReceiveMessageService.shared.stopRecallMessage(item: message, childMessageIds: childMessageIds)
                        if message.status != MessageStatus.READ.rawValue {
                            try MessageDAO.shared.updateUnseenMessageCount(database: db, conversationId: message.conversationId)
                        }
                    }
                    NotificationCenter.default.post(onMainThread: Self.expiredMessageDidDeleteNotification,
                                                    object: nil,
                                                    userInfo: [Self.messageIdKey: id])
                }
            }
            if !expiredMessageIds.isEmpty {
                db.afterNextTransactionCommit { _ in
                    NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: nil)
                }
            }
            try ExpiredMessage
                .filter(expiredMessageIds.contains(ExpiredMessage.column(of: .messageId)))
                .deleteAll(db)
            let nextExpireAt: Int64? = try ExpiredMessage
                .select(ExpiredMessage.column(of: .expireAt))
                .filter(ExpiredMessage.column(of: .expireAt) != nil)
                .order([ExpiredMessage.column(of: .expireAt).asc])
                .fetchOne(db)
            completion(nextExpireAt)
        }
    }
    
}
