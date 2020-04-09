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
    public var conversationCount: Int
    public var unreadCount: Int = 0
    
    public init(circleId: String, name: String, conversationCount: Int, unreadCount: Int) {
        self.circleId = circleId
        self.name = name
        self.conversationCount = conversationCount
        self.unreadCount = unreadCount
    }
    
}

extension CircleItem: Equatable {
    
    public static func == (lhs: CircleItem, rhs: CircleItem) -> Bool {
        lhs.circleId == rhs.circleId
    }
    
}

extension CircleItem: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(circleId)
    }
    
}
