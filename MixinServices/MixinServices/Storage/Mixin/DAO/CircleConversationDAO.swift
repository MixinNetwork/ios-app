import Foundation
import WCDBSwift

final public class CircleConversationDAO {
    
    public static let shared = CircleConversationDAO()
    
    public static let circleConversationsDidChangeNotification = Notification.Name("one.mixin.messenger.circle_conversations.did_change")
    public static let circleIdUserInfoKey = "cid"
    
    public func update(conversation: ConversationResponse) {
        MixinDatabase.shared.transaction { (db) in
            let circleIds = conversation.circles.map { $0.circleId }

            let refreshCirclesIds = try db.getColumn(on: Circle.Properties.circleId, fromTable: Circle.tableName, where: Circle.Properties.circleId.notIn(circleIds)).map { $0.stringValue }
            for circleId in refreshCirclesIds {
                ConcurrentJobQueue.shared.addJob(job: RefreshCircleJob(circleId: circleId))
            }

            let oldCircles: [CircleConversation] = try db.getObjects(on: CircleConversation.Properties.all, fromTable: CircleConversation.tableName, where: CircleConversation.Properties.conversationId == conversation.conversationId && CircleConversation.Properties.circleId.in(circleIds))
            let dict = oldCircles.toDictionary { $0.circleId }

            let objects = conversation.circles.map { (circle) -> CircleConversation in
                let circleConversation = CircleConversation(circleId: circle.circleId,
                                                conversationId: conversation.conversationId,
                                                userId: nil,
                                                createdAt: circle.createdAt,
                                                pinTime: nil)
                if let oldCircleConversation = dict[circle.circleId] {
                    circleConversation.userId = oldCircleConversation.userId
                    circleConversation.pinTime = oldCircleConversation.pinTime
                }
                return circleConversation
            }
            try db.delete(fromTable: CircleConversation.tableName,
                          where: CircleConversation.Properties.conversationId == conversation.conversationId)
            try db.insertOrReplace(objects: objects,
                                   intoTable: CircleConversation.tableName)
        }
    }

    public func insertOrReplace(circleId: String, objects: [CircleConversation], sendNotificationAfterFinished: Bool = true) {
        MixinDatabase.shared.insertOrReplace(objects: objects)

        if sendNotificationAfterFinished {
            let userInfo = [Self.circleIdUserInfoKey: circleId]
            NotificationCenter.default.postOnMain(name: Self.circleConversationsDidChangeNotification, userInfo: userInfo)
        }
    }
    
    public func delete(circleId: String, conversationId: String) {
        MixinDatabase.shared.delete(table: CircleConversation.tableName, condition: CircleConversation.Properties.circleId == circleId && CircleConversation.Properties.conversationId == conversationId)
        let userInfo = [Self.circleIdUserInfoKey: circleId]
        NotificationCenter.default.postOnMain(name: Self.circleConversationsDidChangeNotification, userInfo: userInfo)
    }

    public func delete(circleId: String, conversationIds: [String]) {
        MixinDatabase.shared.delete(table: CircleConversation.tableName, condition: CircleConversation.Properties.circleId == circleId && CircleConversation.Properties.conversationId.in(conversationIds))
        let userInfo = [Self.circleIdUserInfoKey: circleId]
        NotificationCenter.default.postOnMain(name: Self.circleConversationsDidChangeNotification, userInfo: userInfo)
    }
}

fileprivate extension Array {

    public func toDictionary<Key: Hashable>(with selectKey: (Element) -> Key) -> [Key: Element] {
        var dict = [Key: Element]()
        for element in self {
            dict[selectKey(element)] = element
        }
        return dict
    }
    
}
