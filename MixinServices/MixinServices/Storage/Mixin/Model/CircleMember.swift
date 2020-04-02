import UIKit
import WCDBSwift

public class CircleMember: TableDecodable {
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = CircleMember
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case conversationId = "conversation_id"
        case ownerId = "owner_id"
        case category
        case name
        case iconUrl = "icon_url"
        
    }
    
    public let conversationId: String
    public let ownerId: String
    public let category: String
    public let name: String
    public let iconUrl: String
    
    public var badgeImage: UIImage? = nil
    
    public init(conversationId: String, ownerId: String, category: String, name: String, iconUrl: String, badgeImage: UIImage? = nil) {
        self.conversationId = conversationId
        self.ownerId = ownerId
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
