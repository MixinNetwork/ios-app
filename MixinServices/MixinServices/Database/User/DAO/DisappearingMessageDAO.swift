import UIKit
import GRDB

public final class DisappearingMessageDAO: UserDatabaseDAO {
    
    public static let messageIdKey = "mid"

    public static let expiredAtDidUpdateNotification = Notification.Name("one.mixin.services.DisappearingMessageDAO.expiredAtDidUpdate")
    public static let expiredMessageDidDeleteNotification = Notification.Name("one.mixin.services.DisappearingMessageDAO.expiredMessageDidDelete")

    public static let shared = DisappearingMessageDAO()
    
    public func insert(message: DisappearingMessage, database: GRDB.Database) throws {
        try message.save(database)
        if message.expireAt != 0 {
            database.afterNextTransactionCommit { _ in
                NotificationCenter.default.post(onMainThread: Self.expiredAtDidUpdateNotification, object: self)
            }
        }
    }
    
    public func updateExpireAt(for messageId: String, expireAt: Int64?) {
        db.write { db in
            try updateExpireAt(for: messageId, database: db, expireAt: expireAt)
        }
    }

    public func updateExpireAt(for messageId: String, database: GRDB.Database, expireAt: Int64? = nil) throws {
        guard let message = try DisappearingMessage.filter(DisappearingMessage.column(of: .messageId) == messageId).fetchOne(database), message.expireAt == 0 else {
            return
        }
        let expireAt = expireAt ?? Int64(Date().addingTimeInterval(TimeInterval(message.expireIn)).timeIntervalSince1970)
        try DisappearingMessage
            .filter(DisappearingMessage.column(of: .messageId) == messageId)
            .updateAll(database, [DisappearingMessage.column(of: .expireAt).set(to: expireAt)])
        database.afterNextTransactionCommit { _ in
            NotificationCenter.default.post(onMainThread: Self.expiredAtDidUpdateNotification, object: self)
        }
    }
    
    public func removeExpiredMessages(completion: (_ nextExpireAt: Int64?) -> Void) {
        db.write { db in
            let condition: SQLSpecificExpressible = DisappearingMessage.column(of: .expireAt) != 0
                && DisappearingMessage.column(of: .expireAt) <= Int64(Date().timeIntervalSince1970)
            let expiredMessageIds: [String] = try DisappearingMessage
                .select(DisappearingMessage.column(of: .messageId))
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
            try DisappearingMessage
                .filter(expiredMessageIds.contains(DisappearingMessage.column(of: .messageId)))
                .deleteAll(db)
            let nextExpireAt: Int64? = try DisappearingMessage
                .select(DisappearingMessage.column(of: .expireAt))
                .filter(DisappearingMessage.column(of: .expireAt) != 0)
                .order([DisappearingMessage.column(of: .expireAt).asc])
                .fetchOne(db)
            completion(nextExpireAt)
        }
    }
    
    public func getExpireAts(messageIds: [String]) -> [String: Int64] {
        guard !messageIds.isEmpty else {
            return [:]
        }
        let ids = messageIds.joined(separator: "', '")
        let sql = """
        SELECT m.*
        FROM disappearing_messages m
        WHERE m.message_id in ('\(ids)')
        """
        let messages: [DisappearingMessage] = db.select(with: sql)
        return messages.reduce(into: [:]) { map, message in
            map[message.messageId] = message.expireAt
        }
    }
    
}
