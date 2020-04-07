import Foundation
import WCDBSwift

final public class CircleConversationDAO {
    
    public static let shared = CircleConversationDAO()
    
    public static let circleConversationsDidChangeNotification = Notification.Name("one.mixin.messenger.circle_conversations.did_change")
    public static let circleIdUserInfoKey = "cid"
    
    public func update(conversation: ConversationResponse) {
        MixinDatabase.shared.transaction { (db) in
            let objects = conversation.circles.map { (circle) -> CircleConversation in
                let object = CircleConversation(circleId: circle.circleId,
                                                conversationId: conversation.conversationId,
                                                userId: nil,
                                                createdAt: circle.createdAt,
                                                pinTime: nil)
                let oldValue: CircleConversation? = try? db.getObject(on: CircleConversation.Properties.all, fromTable: CircleConversation.tableName, where: CircleConversation.Properties.conversationId == object.conversationId)
                if let old = oldValue {
                    object.userId = old.userId
                    object.pinTime = old.pinTime
                }
                return object
            }
            try db.delete(fromTable: CircleConversation.tableName,
                          where: CircleConversation.Properties.conversationId == conversation.conversationId)
            try db.insertOrReplace(objects: objects,
                                   intoTable: CircleConversation.tableName)
        }
    }
    
    public func insert(_ object: CircleConversation) {
        MixinDatabase.shared.insert(objects: [object])
        let userInfo = [Self.circleIdUserInfoKey: object.circleId]
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.circleConversationsDidChangeNotification,
                                            object: self,
                                            userInfo: userInfo)
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
    
}
