import WCDBSwift

public final class MessageHistoryDAO {
    
    public static let shared = MessageHistoryDAO()
    
    public func isExist(messageId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: MessageHistory.self, condition: MessageHistory.Properties.messageId == messageId)
    }
    
    public func replaceMessageHistory(messageId: String) {
        MixinDatabase.shared.insertOrReplace(objects: [MessageHistory(messageId: messageId)])
    }
    
}
