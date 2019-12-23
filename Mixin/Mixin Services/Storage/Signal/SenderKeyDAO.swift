import Foundation
import WCDBSwift

public class SenderKeyDAO: SignalDAO {

    public static let shared = SenderKeyDAO()

    func getSenderKey(groupId: String, senderId: String) -> SenderKey? {
        return SignalDatabase.shared.getCodable(condition: SenderKey.Properties.groupId == groupId && SenderKey.Properties.senderId == senderId)
    }

    @discardableResult
    func delete(groupId: String, senderId: String) -> Bool {
        let changes = SignalDatabase.shared.delete(table: SenderKey.tableName, condition: SenderKey.Properties.groupId == groupId && SenderKey.Properties.senderId == senderId)
        Logger.write(conversationId: groupId, log: "[SenderKeyDAO][Delete]...senderId:\(senderId)...changes:\(changes)")
        return true
    }

    public func syncGetSenderKeys() -> [SenderKey] {
        return SignalDatabase.shared.getCodables()
    }
    
}
