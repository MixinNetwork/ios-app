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
    
    public init(conversationId: String, messageId: String, mentionsJson: Data, hasRead: Bool) {
        self.conversationId = conversationId
        self.messageId = messageId
        self.mentionsJson = mentionsJson
        self.hasRead = hasRead
    }
    
    public init?(message: Message, isComposedByMe: Bool) {
        guard message.category.hasSuffix("_TEXT"), let content = message.content else {
            return nil
        }
        let numbers = MessageMentionDetector.mentionedIdentityNumbers(from: content)
        guard !numbers.isEmpty else {
            return nil
        }
        var mentions = UserDAO.shared.fullnames(identityNumbers: numbers)
        guard let json = try? JSONEncoder.default.encode(mentions) else {
            return nil
        }
        self.conversationId = message.conversationId
        self.messageId = message.messageId
        self.mentionsJson = json
        if isComposedByMe {
            self.hasRead = true
        } else {
            self.hasRead = mentions[myIdentityNumber] == nil
        }
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
