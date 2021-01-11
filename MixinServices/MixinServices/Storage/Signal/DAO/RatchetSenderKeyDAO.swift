import Foundation
import GRDB

internal class RatchetSenderKeyDAO: SignalDAO {
    
    static let shared = RatchetSenderKeyDAO()
    
    func setRatchetSenderKeyStatus(groupId: String, senderId: String, status: String, sessionId: String?) {
        let address = SignalAddress(name: senderId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        let ratchet = RatchetSenderKey(groupId: groupId, senderId: address.toString(), status: status)
        db.save(ratchet)
    }
    
    func getRatchetSenderKeyStatus(groupId: String, senderId: String, sessionId: String?) -> String? {
        let address = SignalAddress(name: senderId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        let condition: SQLSpecificExpressible = RatchetSenderKey.column(of: .groupId) == groupId
            && RatchetSenderKey.column(of: .senderId) == address.toString()
        let ratchet: RatchetSenderKey? = db.select(where: condition)
        return ratchet?.status
    }
    
    func deleteRatchetSenderKey(groupId: String, senderId: String, sessionId: String?) {
        let address = SignalAddress(name: senderId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        let condition: SQLSpecificExpressible = RatchetSenderKey.column(of: .groupId) == groupId
            && RatchetSenderKey.column(of: .senderId) == address.toString()
        db.delete(RatchetSenderKey.self, where: condition)
    }
    
}
