import Foundation

class MixinPreKeyStore: PreKeyStore {
    
    private let lock = NSLock()
    
    func load(preKey: UInt32) -> Data? {
        PreKeyDAO.shared.getPreKey(with: Int(preKey))?.record
    }
    
    func contains(preKey: UInt32) -> Bool {
        PreKeyDAO.shared.getPreKey(with: Int(preKey)) != nil
    }
    
    func remove(preKey: UInt32) -> Bool {
        PreKeyDAO.shared.deletePreKey(with: Int(preKey))
    }
    
    func store(preKey: Data, for id: UInt32) -> Bool {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        let preKey = PreKey(preKeyId: Int(id), record: preKey)
        return PreKeyDAO.shared.savePreKey(preKey)
    }
    
    @discardableResult
    func store(preKeys: [PreKey]) -> Bool {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        return PreKeyDAO.shared.savePreKeys(preKeys)
    }
    
}
