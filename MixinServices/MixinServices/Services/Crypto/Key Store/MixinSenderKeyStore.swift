import Foundation

class MixinSenderKeyStore: SenderKeyStore {
    
    private let lock = NSLock()
    
    func store(senderKey: Data, for address: SignalSenderKeyName, userRecord: Data?) -> Bool {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        let senderKey = SenderKey(groupId: address.groupId,
                                  senderId: address.sender.toString(),
                                  record: senderKey)
        return SignalDatabase.current.save(senderKey)
    }
    
    func loadSenderKey(for address: SignalSenderKeyName) -> (senderKey: Data, userRecord: Data?)? {
        guard let senderKey = SenderKeyDAO.shared.getSenderKey(groupId: address.groupId, senderId: address.sender.toString()) else {
            return nil
        }
        return (senderKey.record, nil)
    }
    
    func removeSenderKey(senderKeyName: SignalSenderKeyName) {
        SenderKeyDAO.shared.delete(groupId: senderKeyName.groupId, senderId: senderKeyName.sender.toString())
    }
    
}
