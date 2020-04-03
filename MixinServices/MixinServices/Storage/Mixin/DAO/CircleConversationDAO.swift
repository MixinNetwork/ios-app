import Foundation
import WCDBSwift

final public class CircleConversationDAO {
    
    public static let shared = CircleConversationDAO()
    
    public static let circleConversationsDidChangeNotification = Notification.Name("one.mixin.messenger.circle_conversations.did_change")
    
    public func update(conversation: ConversationResponse) {
        let objects = conversation.circles.map { (circle) -> CircleConversation in
            CircleConversation(circleId: circle.circleId,
                               conversationId: conversation.conversationId,
                               createdAt: circle.createdAt)
        }
        MixinDatabase.shared.insertOrReplace(objects: objects)
    }
    
    public func replaceCircleConversations(with circleId: String, objects: [CircleConversation]) {
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: CircleConversation.tableName,
                          where: CircleConversation.Properties.circleId == circleId)
            try db.insertOrReplace(objects: objects,
                                   intoTable: CircleConversation.tableName)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.circleConversationsDidChangeNotification, object: self)
        }
    }
    
    public func delete(circleId: String) {
        MixinDatabase.shared.delete(table: CircleConversation.tableName,
                                    condition: CircleConversation.Properties.circleId == circleId)
    }
    
}
