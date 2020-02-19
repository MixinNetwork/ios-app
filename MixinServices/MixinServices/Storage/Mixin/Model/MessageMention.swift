import WCDBSwift

public struct MessageMention: BaseCodable {
    
    public typealias Mentions = [String: String]
    
    public static let tableName: String = "message_mention"
    
    public let conversationId: String
    public let messageId: String
    public let mentionsJson: Data?
    public let hasRead: Bool
    
    public lazy var mentions: Mentions = {
        guard let json = mentionsJson else {
            return [:]
        }
        let decoded = try? JSONDecoder.default.decode(Mentions.self, from: json)
        return decoded ?? [:]
    }()
    
    public init(conversationId: String, messageId: String, mentionsJson: Data?, hasRead: Bool) {
        self.conversationId = conversationId
        self.messageId = messageId
        self.mentionsJson = mentionsJson
        self.hasRead = hasRead
    }
    
}

extension MessageMention {
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = MessageMention
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                messageId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case mentionsJson = "mentions"
        case hasRead = "has_read"
        
    }
    
}
