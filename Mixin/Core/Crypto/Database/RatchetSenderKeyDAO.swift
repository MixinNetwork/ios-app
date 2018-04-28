import Foundation
import WCDBSwift

class RatchetSenderKeyDAO: SignalDAO {

    static let shared = RatchetSenderKeyDAO()

    func getRatchetSenderKey(groupId: String, senderId: String) -> RatchetSenderKey? {
        return SignalDatabase.shared.getCodable(condition: RatchetSenderKey.Properties.groupId == groupId && RatchetSenderKey.Properties.senderId == senderId)
    }

    func delete(groupId: String, senderId: String) {
        SignalDatabase.shared.delete(table: RatchetSenderKey.tableName, condition: RatchetSenderKey.Properties.groupId == groupId && RatchetSenderKey.Properties.senderId == senderId)
    }


}
