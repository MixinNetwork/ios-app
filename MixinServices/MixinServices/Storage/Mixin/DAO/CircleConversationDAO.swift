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
    
    public func insert(_ objects: [CircleConversation]) {
        MixinDatabase.shared.insert(objects: objects)
        let changedCircleIds = Set(objects.map(\.circleId))
        let userInfos = changedCircleIds.map { [Self.circleIdUserInfoKey: $0] }
        DispatchQueue.main.async {
            for userInfo in userInfos {
                NotificationCenter.default.post(name: Self.circleConversationsDidChangeNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
    }
    
    public func replaceCircleConversations(with circleId: String, objects: [CircleConversation]) {
        MixinDatabase.shared.transaction { (db) in
            for object in objects {
                let oldValue: CircleConversation? = try? db.getObject(on: CircleConversation.Properties.all, fromTable: CircleConversation.tableName, where: CircleConversation.Properties.conversationId == object.conversationId)
                if let old = oldValue {
                    object.userId = old.userId
                    object.pinTime = old.pinTime
                }
            }
            
            try db.delete(fromTable: CircleConversation.tableName,
                          where: CircleConversation.Properties.circleId == circleId)
            try db.insertOrReplace(objects: objects,
                                   intoTable: CircleConversation.tableName)
        }
        let userInfo = [Self.circleIdUserInfoKey: circleId]
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.circleConversationsDidChangeNotification, object: self, userInfo: userInfo)
        }
    }
    
    public func delete(circleId: String) {
        MixinDatabase.shared.delete(table: CircleConversation.tableName,
                                    condition: CircleConversation.Properties.circleId == circleId)
    }
    
    public func delete(circleId: String, conversationId: String) {
        MixinDatabase.shared.delete(table: CircleConversation.tableName, condition: CircleConversation.Properties.circleId == circleId && CircleConversation.Properties.conversationId == conversationId)
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
