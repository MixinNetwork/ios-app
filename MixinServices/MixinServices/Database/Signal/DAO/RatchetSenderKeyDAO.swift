import Foundation
import GRDB

internal class RatchetSenderKeyDAO: SignalDAO {
    
    static let shared = RatchetSenderKeyDAO()
    
    func getRatchetSenderKey(groupId: String, senderId: String) -> RatchetSenderKey? {
        let condition: SQLSpecificExpressible = RatchetSenderKey.column(of: .groupId) == groupId
            && RatchetSenderKey.column(of: .senderId) == senderId
        return db.select(where: condition)
    }
    
    func delete(groupId: String, senderId: String) {
        let condition: SQLSpecificExpressible = RatchetSenderKey.column(of: .groupId) == groupId
            && RatchetSenderKey.column(of: .senderId) == senderId
        db.delete(RatchetSenderKey.self, where: condition)
    }
    
    func saveRatchetSenderKey(_ key: RatchetSenderKey) {
        db.save(key)
    }
    
    func getRatchetSenderKeyStatus(groupId: String, senderId: String, sessionId: String?) -> String? {
        getRatchetSenderKey(groupId: groupId, senderId: senderId)?.status
    }
    
    func deleteRatchetSenderKey(groupId: String, senderId: String) {
        delete(groupId: groupId, senderId: senderId)
    }
    
}
