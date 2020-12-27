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
    
    func setRatchetSenderKeyStatus(groupId: String, senderId: String, status: String, sessionId: String?) {
        let address = SignalAddress(name: senderId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        let ratchet = RatchetSenderKey(groupId: groupId, senderId: address.toString(), status: status)
        db.save(ratchet)
    }
    
    func getRatchetSenderKeyStatus(groupId: String, senderId: String, sessionId: String?) -> String? {
        let address = SignalAddress(name: senderId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        return getRatchetSenderKey(groupId: groupId, senderId: address.toString())?.status
    }
    
    func deleteRatchetSenderKey(groupId: String, senderId: String, sessionId: String?) {
        let address = SignalAddress(name: senderId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        delete(groupId: groupId, senderId: address.toString())
    }
    
}
