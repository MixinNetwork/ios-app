import WCDBSwift

public struct MessageMention: BaseCodable {
    
    public typealias Mentions = [String: String]
    
    public static let tableName: String = "message_mentions"
    
    public let conversationId: String
    public let messageId: String
    public let mentionsJson: Data
    public let hasRead: Bool
    
    public lazy var mentions: Mentions = {
        let decoded = try? JSONDecoder.default.decode(Mentions.self, from: mentionsJson)
        return decoded ?? [:]
    }()
    
    public init(conversationId: String, messageId: String, mentions: Mentions, hasRead: Bool) {
        let json = (try? JSONEncoder.default.encode(mentions)) ?? Data()
        self.init(conversationId: conversationId,
                  messageId: messageId,
                  mentionsJson: json,
                  hasRead: hasRead)
    }
    
    public init?(message: Message, quotedMessage: MessageItem?) {
        var mentions: Mentions
        if message.category.hasSuffix("_TEXT"), let content = message.content {
            let numbers = MessageMentionDetector.identityNumbers(from: content)
            mentions = UserDAO.shared.mentionRepresentation(identityNumbers: numbers)
        } else {
            mentions = [:]
        }
        if let quoted = quotedMessage, message.userId != myUserId, quoted.userId == myUserId {
            mentions[myIdentityNumber] = myFullname
        }

        if mentions.count == 0 {
            return nil
        }
        
        let hasRead: Bool
        if message.userId == myUserId {
            hasRead = true
        } else {
            hasRead = mentions[myIdentityNumber] == nil
        }
        
        self.init(conversationId: message.conversationId,
                  messageId: message.messageId,
                  mentions: mentions,
                  hasRead: hasRead)
    }
    
    private init(conversationId: String, messageId: String, mentionsJson: Data, hasRead: Bool) {
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
        public static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_conversation_indexs": IndexBinding(indexesBy: conversationId, hasRead),
            ]
        }
        
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case mentionsJson = "mentions"
        case hasRead = "has_read"
        
    }
    
}
