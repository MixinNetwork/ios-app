import Foundation

class SenderKeyStore: BaseSignalStore, SenderKeyStoreDelegate {

    func loadSenderKey(senderKeyName: SignalSenderKeyName) -> Data? {
        guard let senderKey = SenderKeyDAO.shared.getSenderKey(groupId: senderKeyName.groupId, senderId: senderKeyName.sender.toString()) else {
            return nil
        }
        return senderKey.record
    }

    func store(senderKey: Data, for senderKeyName: SignalSenderKeyName) -> Bool {
        return SenderKeyDAO.shared.insertOrReplace(obj: SenderKey(groupId: senderKeyName.groupId, senderId: senderKeyName.sender.toString(), record: senderKey))
    }

    func removeSenderKey(senderKeyName: SignalSenderKeyName) {
        let result = SenderKeyDAO.shared.delete(groupId: senderKeyName.groupId, senderId: senderKeyName.sender.toString())
        FileManager.default.writeLog(conversationId: senderKeyName.groupId, log: "[SenderKeyStore][removeSenderKey][\(result)]...\(senderKeyName.sender.toString())")
    }
}
