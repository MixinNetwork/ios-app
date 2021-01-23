import Foundation
import GRDB

final public class CircleConversationDAO: UserDatabaseDAO {
    
    public static let shared = CircleConversationDAO()
    
    public static let circleConversationsDidChangeNotification = Notification.Name("one.mixin.messenger.circle_conversations.did_change")
    public static let circleIdUserInfoKey = "cid"
    
    public func update(conversation: ConversationResponse) {
        db.write { (db) in
            let circleIds = conversation.circles.map { $0.circleId }
            let refreshRequest = Circle
                .select(Circle.column(of: .circleId))
                .filter(!circleIds.contains(Circle.column(of: .circleId)))
            let refreshCirclesIds = try String.fetchAll(db, refreshRequest)
            for circleId in refreshCirclesIds {
                ConcurrentJobQueue.shared.addJob(job: RefreshCircleJob(circleId: circleId))
            }
            let oldCircleCondition: SQLSpecificExpressible = CircleConversation.column(of: .conversationId) == conversation.conversationId
                && circleIds.contains(CircleConversation.column(of: .circleId))
            let oldCircles = try CircleConversation.fetchAll(db, CircleConversation.filter(oldCircleCondition))
            var dict: [String: CircleConversation] = [:]
            for circle in oldCircles {
                dict[circle.circleId] = circle
            }
            
            let objects = conversation.circles.map { (circle) -> CircleConversation in
                let oldCircleConversation = dict[circle.circleId]
                let circleConversation = CircleConversation(circleId: circle.circleId,
                                                            conversationId: conversation.conversationId,
                                                            userId: oldCircleConversation?.userId,
                                                            createdAt: circle.createdAt,
                                                            pinTime: oldCircleConversation?.pinTime)
                return circleConversation
            }
            
            try CircleConversation
                .filter(CircleConversation.column(of: .conversationId) == conversation.conversationId)
                .deleteAll(db)
            try objects.save(db)
        }
    }
    
    public func save(circleId: String, objects: [CircleConversation], sendNotificationAfterFinished: Bool = true) {
        db.save(objects) { _ in
            if sendNotificationAfterFinished {
                let userInfo = [Self.circleIdUserInfoKey: circleId]
                NotificationCenter.default.post(onMainThread: Self.circleConversationsDidChangeNotification, object: self, userInfo: userInfo)
            }
        }
    }
    
    public func delete(circleId: String, conversationId: String) {
        let condition: SQLSpecificExpressible = CircleConversation.column(of: .circleId) == circleId
            && CircleConversation.column(of: .conversationId) == conversationId
        db.delete(CircleConversation.self, where: condition) { _ in
            let userInfo = [Self.circleIdUserInfoKey: circleId]
            NotificationCenter.default.post(onMainThread: Self.circleConversationsDidChangeNotification, object: self, userInfo: userInfo)
        }
    }
    
    public func delete(circleId: String, conversationIds: [String]) {
        let condition: SQLSpecificExpressible = CircleConversation.column(of: .circleId) == circleId
            && conversationIds.contains(CircleConversation.column(of: .conversationId))
        db.delete(CircleConversation.self, where: condition) { _ in
            let userInfo = [Self.circleIdUserInfoKey: circleId]
            NotificationCenter.default.post(onMainThread: Self.circleConversationsDidChangeNotification, object: self, userInfo: userInfo)
        }
    }
    
}
