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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        mediaSize = try container.decodeIfPresent(Int64.self, forKey: .mediaSize) ?? 0
        messageCount = try container.decodeIfPresent(Int.self, forKey: .messageCount) ?? 0
    }
    
}

