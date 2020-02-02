import WCDBSwift

public final class ResendSessionMessageDAO {
    
    public static let shared = ResendSessionMessageDAO()
    
    public func isExist(messageId: String, userId: String, sessionId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: ResendSessionMessage.self, condition: ResendSessionMessage.Properties.messageId == messageId && ResendSessionMessage.Properties.userId == userId && ResendSessionMessage.Properties.sessionId == sessionId)
    }
    
}
