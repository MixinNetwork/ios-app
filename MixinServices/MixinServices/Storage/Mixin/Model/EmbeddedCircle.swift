import Foundation
import WCDBSwift

public class EmbeddedCircle: BaseDecodable {
    
    public enum Category: Int, CaseIterable {
        case all = 0
//        case strangers
//        case bots
//        case contacts
    }
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = EmbeddedCircle
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case conversationCount = "conversation_count"
        case unreadCount = "unread_count"
        
    }
    
    public static let tableName = Conversation.tableName
    
    public let conversationCount: Int
    public let unreadCount: Int
    
    public init(conversationCount: Int, unreadCount: Int) {
        self.conversationCount = conversationCount
        self.unreadCount = unreadCount
    }
    
}
