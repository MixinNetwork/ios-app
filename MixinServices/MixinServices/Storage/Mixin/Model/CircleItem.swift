import Foundation
import GRDB

public final class CircleItem {
    
    public let circleId: String
    public let name: String
    public let unreadCount: Int
    
    public var conversationCount: Int
    
    public init(circleId: String, name: String, conversationCount: Int, unreadCount: Int) {
        self.circleId = circleId
        self.name = name
        self.conversationCount = conversationCount
        self.unreadCount = unreadCount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        circleId = try container.decode(String.self, forKey: .circleId)
        name = try container.decode(String.self, forKey: .name)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        conversationCount = try container.decode(Int.self, forKey: .conversationCount)
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

extension CircleItem: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case circleId = "circle_id"
        case name
        case conversationCount = "conversation_count"
        case unreadCount = "unread_count"
    }
    
}
