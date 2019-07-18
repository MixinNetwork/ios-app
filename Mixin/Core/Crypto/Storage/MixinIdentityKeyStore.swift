import Foundation
import UIKit

class MixinIdentityKeyStore: IdentityKeyStore {
    
    private let lock = NSLock()

    func identityKeyPair() -> KeyPair? {
        return IdentityDao.shared.getLocalIdentity()?.getIdentityKeyPair()
    }

    func localRegistrationId() -> UInt32? {
        guard let registrationId = IdentityDao.shared.getLocalIdentity()?.registrationId else {
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
            var userInfo = UIApplication.getTrackUserInfo()
            userInfo["address"] = address.name
            UIApplication.trackError("IdentityKeyStore", action: "Saving new identity failed, identity is nil", userInfo: userInfo)
            return false
        }
        let signalAddress = address.name
        #if DEBUG
        print("======IdentityKeyStore...save...Saving new identity...")
        #endif
        if !IdentityDao.shared.insertOrReplace(obj: Identity(address: signalAddress, registrationId: nil, publicKey: identityKey, privateKey: nil, nextPreKeyId: nil, timestamp: Date().timeIntervalSince1970)) {
            var userInfo = UIApplication.getTrackUserInfo()
            userInfo["address"] = address.name
            UIApplication.trackError("IdentityKeyStore", action: "Saving new identity failed", userInfo: userInfo)
        }
        return true
    }
}




