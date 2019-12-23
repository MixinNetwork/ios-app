import Foundation
import WCDBSwift

internal class RatchetSenderKeyDAO: SignalDAO {
    
    static let shared = RatchetSenderKeyDAO()
    
    func getRatchetSenderKey(groupId: String, senderId: String) -> RatchetSenderKey? {
        return SignalDatabase.shared.getCodable(condition: RatchetSenderKey.Properties.groupId == groupId && RatchetSenderKey.Properties.senderId == senderId)
    }
    
    func delete(groupId: String, senderId: String) {
        SignalDatabase.shared.delete(table: RatchetSenderKey.tableName, condition: RatchetSenderKey.Properties.groupId == groupId && RatchetSenderKey.Properties.senderId == senderId)
    }
    
    func setRatchetSenderKeyStatus(groupId: String, senderId: String, status: String, sessionId: String?) {
        let address = SignalAddress(name: senderId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        let ratchet = RatchetSenderKey(groupId: groupId, senderId: address.toString(), status: status)
        SignalDatabase.shared.insertOrReplace(objects: [ratchet])
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
