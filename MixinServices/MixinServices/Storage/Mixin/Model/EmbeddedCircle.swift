import Foundation
import GRDB

public final class EmbeddedCircle {
    
    public enum Category: Int, CaseIterable {
        case all = 0
//        case strangers
//        case bots
//        case contacts
    }
    
    public let conversationCount: Int
    public let unreadCount: Int
    
    public init(conversationCount: Int, unreadCount: Int) {
        self.conversationCount = conversationCount
        self.unreadCount = unreadCount
    }
    
}

extension EmbeddedCircle: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case conversationCount = "conversation_count"
        case unreadCount = "unread_count"
    }
    
}
