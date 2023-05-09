import Foundation
import GRDB

public struct LargeQuoteMessage {
 
    public let rowId: Int
    public let messageId: String
    public let quoteMessageId: String
    public let quoteContent: Data
    
}

extension LargeQuoteMessage: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case rowId = "rowid"
        case messageId = "id"
        case quoteMessageId = "quote_message_id"
        case quoteContent = "quote_content"
    }
    
}
