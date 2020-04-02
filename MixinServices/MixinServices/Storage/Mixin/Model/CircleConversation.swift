import UIKit
import WCDBSwift

public class CircleConversation: BaseCodable {
    
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
    
    public init(circleId: String, conversationId: String, createdAt: String) {
        self.circleId = circleId
        self.conversationId = conversationId
        self.createdAt = createdAt
    }
    
}
