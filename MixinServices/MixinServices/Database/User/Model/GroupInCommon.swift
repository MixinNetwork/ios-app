import Foundation
import GRDB

public struct GroupInCommon {
    
    public let conversationId: String
    public let iconUrl: String
    public let name: String
    public let participantsCount: Int
    
}

extension GroupInCommon: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case iconUrl = "icon_url"
        case name
        case participantsCount
    }
    
}
