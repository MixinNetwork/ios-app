import WCDBSwift

public final class MessageMentionDAO {
    
    public static let shared = MessageMentionDAO()
    
    public func read(messageId: String) {
        MixinDatabase.shared.update(maps: [(MessageMention.Properties.hasRead, true)],
                                    tableName: MessageMention.tableName,
                                    condition: MessageMention.Properties.messageId == messageId)
    }
    
}
