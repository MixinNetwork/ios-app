import Foundation
import GRDB

public class SenderKeyDAO: SignalDAO {
    
    public static let shared = SenderKeyDAO()
    
    func getSenderKey(groupId: String, senderId: String) -> SenderKey? {
        let condition: SQLSpecificExpressible = SenderKey.column(of: .groupId) == groupId
            && SenderKey.column(of: .senderId) == senderId
        return db.select(where: condition)
    }
    
    @discardableResult
    func delete(groupId: String, senderId: String) -> Bool {
        let condition: SQLSpecificExpressible = SenderKey.column(of: .groupId) == groupId
            && SenderKey.column(of: .senderId) == senderId
        let changes = db.delete(SenderKey.self, where: condition)
        Logger.write(conversationId: groupId, log: "[SenderKeyDAO][Delete]...senderId:\(senderId)...changes:\(changes)")
        return true
    }
    
    public func getAllSenderKeys() -> [SenderKey] {
        db.selectAll()
    }
    
}
