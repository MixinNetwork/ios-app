import Foundation

internal class CryptoUserDefault {

    static let shared = CryptoUserDefault()
    private let mediumMaxValue: UInt32 = UInt32.max / 2

    private let keyIsLoaded = "prekey_is_loaded"
    private let keySyncSession = "is_sync_session"
    private let keyRefreshOneTimePreKey = "refresh_one_time_pre_key"
    private let keyStatusOffset = "status_offset"
    private let keyNextPrekeyID = "next_prekey_id"
    private let keyNextSignedPrekeyID = "next_signed_prekey_id"
    private let keyEncryptIterator = "encrypt_iterator"

    let session = UserDefaults(suiteName: SuiteName.crypto)!

    var isLoaded: Bool {
        get {
            return session.bool(forKey: keyIsLoaded)
        }
        set {
            session.set(newValue, forKey: keyIsLoaded)
        }
    }

    var isSyncSession: Bool {
        get {
            return session.bool(forKey: keySyncSession)
        }
        set {
            session.set(newValue, forKey: keySyncSession)
        }
    }

    var refreshOneTimePreKey: TimeInterval {
        get {
            return session.double(forKey: keyRefreshOneTimePreKey)
        }
        set {
            session.set(newValue, forKey: keyRefreshOneTimePreKey)
        }
    }

    var statusOffset: Int64 {
        get {
            return (session.object(forKey: keyStatusOffset) as? Int64) ?? CommonUserDefault.shared.lastUpdateOrInstallTime.toUTCDate().nanosecond()
        }
        set {
            session.set(newValue, forKey: keyStatusOffset)
        }
    }

    var prekeyOffset: UInt32 {
        get {
            return (session.object(forKey: keyNextPrekeyID) as? UInt32) ?? random(min: 1000, max: mediumMaxValue)
        }
        set {
            session.set(newValue, forKey: keyNextPrekeyID)
        }
    }

    var signedPrekeyOffset: UInt32 {
        get {
            return (session.object(forKey: keyNextSignedPrekeyID) as? UInt32) ?? random(min: 1000, max: mediumMaxValue)
        }
        set {
            session.set(newValue, forKey: keyNextSignedPrekeyID)
        }
    }

    var iterator: UInt64 {
        get {
            return max((session.object(forKey: keyEncryptIterator) as? UInt64) ?? 1, 1)
        }
        set {
            session.set(newValue, forKey: keyEncryptIterator)
        }
    }
    
    func reset() {
        session.removeObject(forKey: keyIsLoaded)
        session.removeObject(forKey: keySyncSession)
        session.removeObject(forKey: keyRefreshOneTimePreKey)
        session.removeObject(forKey: keyNextPrekeyID)
        session.removeObject(forKey: keyNextSignedPrekeyID)
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
