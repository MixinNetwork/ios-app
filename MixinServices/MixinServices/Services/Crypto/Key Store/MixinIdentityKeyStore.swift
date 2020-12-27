import Foundation

class MixinIdentityKeyStore: IdentityKeyStore {
    
    private let lock = NSLock()
    
    func identityKeyPair() -> KeyPair? {
        return IdentityDAO.shared.getLocalIdentity()?.getIdentityKeyPair()
    }
    
    func localRegistrationId() -> UInt32? {
        guard let registrationId = IdentityDAO.shared.getLocalIdentity()?.registrationId else {
            return nil
        }
        return UInt32(registrationId)
    }
    
    func isTrusted(identity: Data, for address: SignalAddress) -> Bool? {
        return true
    }
    
    func save(identity: Data?, for address: SignalAddress) -> Bool {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        guard let identityKey = identity else {
            reporter.report(error: MixinServicesError.saveIdentity)
            return false
        }
        let identity = Identity(address: address.name,
                                registrationId: nil,
                                publicKey: identityKey,
                                privateKey: nil,
                                nextPreKeyId: nil,
                                timestamp: Date().timeIntervalSince1970)
        SignalDatabase.current.save(identity)
        return true
    }
    
    func removeIdentity(address: SignalAddress) {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        IdentityDAO.shared.deleteIdentity(address: address.name)
    }
    
}
