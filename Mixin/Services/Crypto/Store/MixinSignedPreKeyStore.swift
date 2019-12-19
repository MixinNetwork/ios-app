import Foundation

class MixinSignedPreKeyStore: SignedPreKeyStore {

    private let lock = NSLock()

    func load(signedPreKey: UInt32) -> Data? {
        return SignedPreKeyDAO.shared.getSignedPreKey(signedPreKeyId: Int(signedPreKey))?.record
    }

    func contains(signedPreKey: UInt32) -> Bool {
        return SignedPreKeyDAO.shared.getSignedPreKey(signedPreKeyId: Int(signedPreKey)) != nil
    }

    func remove(signedPreKey: UInt32) -> Bool {
        return SignedPreKeyDAO.shared.delete(signedPreKeyId: Int(signedPreKey))
    }

    func store(signedPreKey: Data, for id: UInt32) -> Bool {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        return SignedPreKeyDAO.shared.insertOrReplace(obj: SignedPreKey(preKeyId: Int(id), record: signedPreKey, timestamp: Date().timeIntervalSince1970))
    }

}
