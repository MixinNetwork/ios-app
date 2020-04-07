import UIKit
import WCDBSwift

public class CircleMember: TableDecodable {
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = CircleMember
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case conversationId = "conversation_id"
        case userId = "user_id"
        case category
        case name
        case iconUrl = "icon_url"
        
    }
    
    public let conversationId: String
    public let userId: String?
    public let category: String
    public let name: String
    public let iconUrl: String
    
    public var badgeImage: UIImage? = nil
    
    public init(conversationId: String, userId: String, category: String, name: String, iconUrl: String, badgeImage: UIImage? = nil) {
        self.conversationId = conversationId
        self.userId = userId
        self.category = category
        self.name = name
        self.iconUrl = iconUrl
        self.badgeImage = badgeImage
    }
    
    public func matches(lowercasedKeyword keyword: String) -> Bool {
        name.lowercased().contains(keyword)
    }
    
}

extension CircleMember: Equatable {
    
    public static func == (lhs: CircleMember, rhs: CircleMember) -> Bool {
        lhs.conversationId == rhs.conversationId
    }
    
}

extension CircleMember: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(conversationId)
    }
    
}
