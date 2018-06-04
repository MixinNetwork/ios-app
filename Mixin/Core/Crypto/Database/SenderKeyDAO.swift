import Foundation
import WCDBSwift

class SenderKeyDAO: SignalDAO {

    static let shared = SenderKeyDAO()

    func getSenderKey(groupId: String, senderId: String) -> SenderKey? {
        return SignalDatabase.shared.getCodable(condition: SenderKey.Properties.groupId == groupId && SenderKey.Properties.senderId == senderId)
    }

    @discardableResult
    func delete(groupId: String, senderId: String) -> Bool {
        SignalDatabase.shared.delete(table: SenderKey.tableName, condition: SenderKey.Properties.groupId == groupId && SenderKey.Properties.senderId == senderId)
        return true
    }
    
}
