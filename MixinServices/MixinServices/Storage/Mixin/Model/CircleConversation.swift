import UIKit
import WCDBSwift

class CircleConversation: BaseCodable {
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = CircleConversation
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        public static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: conversationId, circleId)
            ]
        }
        
        case circleId = "circle_id"
        case conversationId = "conversation_id"
        case createdAt = "created_at"
        
    }
    
    public static let tableName: String = "circle_conversations"
    
    public let circleId: String
    public let conversationId: String
    public let createdAt: String
    
}
