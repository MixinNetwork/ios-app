import Foundation

class CryptoUserDefault {

    static let shared = CryptoUserDefault()
    private let mediumMaxValue: UInt32 = UInt32.max / 2

    private let keyIsLoaded = "prekey_is_loaded"
    private let keyRotateSignedPrekey = "rotate_signed_pre_key"
    private let keyStatusOffset = "status_offset"
    private let NEXT_PREKEY_ID = "next_prekey_id"
    private let NEXT_SIGNED_PREKEY_ID = "next_signed_prekey_id"
    private let keyEncryptIterator = "encrypt_iterator"
    private let profileKeyKey = "profile_key"
    
    let session = UserDefaults(suiteName: SuiteName.crypto)!

    var isLoaded: Bool {
        get {
            return session.bool(forKey: keyIsLoaded)
        }
        set {
            session.set(newValue, forKey: keyIsLoaded)
        }
    }

    var rotateSignedPrekey: TimeInterval {
        get {
            return session.double(forKey: keyRotateSignedPrekey)
        }
        set {
            session.set(newValue, forKey: keyRotateSignedPrekey)
        }
    }

    var statusOffset: Int64 {
        get {
            return session.object(forKey: keyStatusOffset) as? Int64 ?? Date().nanosecond()
        }
        set {
            session.set(newValue, forKey: keyStatusOffset)
        }
    }

    var prekeyOffset: UInt32 {
        get {
            return (session.object(forKey: NEXT_PREKEY_ID) as? UInt32) ?? random(min: 1000, max: mediumMaxValue)
        }
        set {
            session.set(newValue, forKey: NEXT_PREKEY_ID)
        }
    }

    var signedPrekeyOffset: UInt32 {
        get {
            return (session.object(forKey: NEXT_SIGNED_PREKEY_ID) as? UInt32) ?? random(min: 1000, max: mediumMaxValue)
        }
        set {
            session.set(newValue, forKey: NEXT_SIGNED_PREKEY_ID)
        }
    }

    var iterator: UInt64 {
        get {
            return (session.object(forKey: keyEncryptIterator) as? UInt64) ?? 1
        }
        set {
            session.set(newValue, forKey: keyEncryptIterator)
        }
    }
    
    var profileKey: Data? {
        get {
            return session.data(forKey: profileKeyKey)
        }
        set {
            session.set(newValue, forKey: profileKeyKey)
        }
    }
    
    func reset() {
        session.removeObject(forKey: keyIsLoaded)
        session.removeObject(forKey: keyRotateSignedPrekey)
        session.removeObject(forKey: keyStatusOffset)
        session.removeObject(forKey: keyEncryptIterator)
        session.synchronize()
    }

    private func random(min: UInt32, max: UInt32) -> UInt32 {
        var result = arc4random_uniform(max)
        if result < min {
            result = min
        }
        return result
    }
}
