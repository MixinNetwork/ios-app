import WCDBSwift

public final class MessageHistoryDAO {

    static let shared = MessageHistoryDAO()

    func isExist(messageId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: MessageHistory.self, condition: MessageHistory.Properties.messageId == messageId)
    }

    func replaceMessageHistory(messageId: String) {
        MixinDatabase.shared.insertOrReplace(objects: [MessageHistory(messageId: messageId)])
    }
}

