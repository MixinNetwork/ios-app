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
    
    public func updateExpireAt(for messageId: String, database: GRDB.Database) throws {
        guard let message = try DisappearingMessage.filter(DisappearingMessage.column(of: .messageId) == messageId).fetchOne(database), message.expireAt == 0 else {
            return
        }
        let expireAt = UInt64(Date().addingTimeInterval(TimeInterval(message.expireIn)).timeIntervalSince1970)
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
                .fetchAll(db)
            let expiredMessages = try MessageDAO.shared.getFullMessages(messageIds: expiredMessageIds)
            for id in expiredMessageIds {
                let (deleted, childMessageIds) = try MessageDAO.shared.deleteMessage(id: id, with: db)
                if deleted {
                    if let message = expiredMessages.first(where: { $0.messageId == id }) {
                        ReceiveMessageService.shared.stopRecallMessage(item: message, childMessageIds: childMessageIds)
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
    
}
