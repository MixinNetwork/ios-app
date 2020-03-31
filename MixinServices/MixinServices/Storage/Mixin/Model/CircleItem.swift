import UIKit
import WCDBSwift

public class CircleItem: TableDecodable {
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = CircleItem
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case circleId = "circle_id"
        case name
        case conversationCount = "conversation_count"
        case unreadCount = "unread_count"
        
    }
    
    public let circleId: String
    public let name: String
    public let conversationCount: Int
    public let unreadCount: Int
    
    public init(circleId: String, name: String, conversationCount: Int, unreadCount: Int) {
        self.circleId = circleId
        self.name = name
        self.conversationCount = conversationCount
        self.unreadCount = unreadCount
    }
    
}
