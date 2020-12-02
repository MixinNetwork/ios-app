import Foundation

class MixinPreKeyStore: PreKeyStore {
    
    private let lock = NSLock()
    
    func load(preKey: UInt32) -> Data? {
        return PreKeyDAO.shared.getPreKey(preKeyId: Int(preKey))?.record
    }
    
    func contains(preKey: UInt32) -> Bool {
        return PreKeyDAO.shared.getPreKey(preKeyId: Int(preKey)) != nil
    }
    
    func remove(preKey: UInt32) -> Bool {
        return PreKeyDAO.shared.deleteIdentity(preKeyId: Int(preKey))
    }
    
    func store(preKey: Data, for id: UInt32) -> Bool {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        let preKey = PreKey(preKeyId: Int(id), record: preKey)
        return SignalDatabase.current.save(preKey)
    }
    
    @discardableResult
    func store(preKeys: [PreKey]) -> Bool {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        return SignalDatabase.current.save(preKeys)
    }
    
}
