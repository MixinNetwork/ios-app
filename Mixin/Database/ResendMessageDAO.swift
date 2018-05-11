import WCDBSwift

final class ResendMessageDAO {

    static let shared = ResendMessageDAO()

    func isExist(messageId: String, userId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: ResendMessage.self, condition: ResendMessage.Properties.messageId == messageId && ResendMessage.Properties.userId == userId)
    }

}

