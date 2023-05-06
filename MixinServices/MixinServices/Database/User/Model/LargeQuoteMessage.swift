import Foundation
import GRDB

public struct LargeQuoteMessage {
 
    public let rowId: Int
    public let conversationId: String
    public let quoteMessageId: String
    
}

extension LargeQuoteMessage: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case rowId = "rowid"
        case conversationId = "conversation_id"
        case quoteMessageId = "quote_message_id"
    }
    
}
