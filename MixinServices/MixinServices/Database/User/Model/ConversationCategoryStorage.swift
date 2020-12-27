import Foundation
import GRDB

public struct ConversationCategoryStorage {
    
    public let category: String
    public let mediaSize: Int64
    public let messageCount: Int
    
}

extension ConversationCategoryStorage: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case category
        case mediaSize
        case messageCount
    }
    
}

