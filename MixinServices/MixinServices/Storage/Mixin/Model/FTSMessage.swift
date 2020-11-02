import WCDBSwift

public struct FTSMessage: BaseCodable {
    
    public static let tableName = "fts_messages"
    
    public var messageId: String
    public var conversationId: String
    public var content: String
    public var name: String
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = FTSMessage
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        public static var virtualTableBinding: VirtualTableBinding? {
            return VirtualTableBinding(with: .fts3, and: ModuleArgument(with: .WCDB))
        }
        
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case content
        case name
        
    }
    
}
