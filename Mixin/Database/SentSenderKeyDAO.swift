import WCDBSwift
import UIKit

final class SentSenderKeyDAO {

    static let shared = SentSenderKeyDAO()

    func replace(_ key: SentSenderKey) {
        MixinDatabase.shared.insertOrReplace(objects: [key])
    }

    func batchUpdate(conversationId: String, messages: [BlazeSignalMessage]) {
        let keys = messages.map{ SentSenderKey(conversationId: conversationId, userId: $0.recipientId, sentToServer: SentSenderKeyStatus.SENT.rawValue) }
        MixinDatabase.shared.insertOrReplace(objects: keys)
    }

    func batchInsert(conversationId: String, messages: [String], status: Int) {
        let keys = messages.map { SentSenderKey(conversationId: conversationId, userId: $0, sentToServer: status)}
        MixinDatabase.shared.insertOrReplace(objects: keys)
    }

    func delete(conversationId: String) {
        MixinDatabase.shared.delete(table: SentSenderKey.tableName, condition: SentSenderKey.Properties.conversationId == conversationId)
    }
}

