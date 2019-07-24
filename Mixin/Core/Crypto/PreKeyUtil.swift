import Foundation

class PreKeyUtil {

    static let LOCAL_REGISTRATION_ID = "local_registration_id"
    static let BATCH_SIZE: Int = 700


    static func generatePreKeys() throws -> [UInt32 : SessionPreKey] {
        let preKeyIdOffset = CryptoUserDefault.shared.prekeyOffset
        let records = try Signal.generatePreKeys(start: preKeyIdOffset, count: BATCH_SIZE)
        CryptoUserDefault.shared.prekeyOffset = preKeyIdOffset + UInt32(BATCH_SIZE) + 1
        let store = MixinPreKeyStore()
        var dict = [UInt32 : SessionPreKey]()
        let preKeys = records.compactMap { (record) -> PreKey? in
            guard let data = try? record.data() else {
                return nil
            }
            dict[record.id] = record
            return PreKey(preKeyId: Int(record.id), record: data)
        }
        store.store(preKeys: preKeys)
        return dict
    }

    static func getIdentityKeyPair() throws -> KeyPair {
        guard let identity = IdentityDao.shared.getLocalIdentity() else {
            var userInfo = UIApplication.getTrackUserInfo()
            userInfo["error"] = "local identity nil"
            userInfo["identityCount"] = "\(IdentityDao.shared.getCount())"
            UIApplication.traceError(code: ReportErrorCode.logoutError, userInfo: userInfo)
            throw SignalError.noData
        }
        return identity.getIdentityKeyPair()
    }

    static func generateSignedPreKey(identityKeyPair : KeyPair) throws -> SessionSignedPreKey {
        let signedPreKeyOffset = CryptoUserDefault.shared.signedPrekeyOffset
        let record = try Signal.generate(signedPreKey: signedPreKeyOffset, identity: identityKeyPair, timestamp: currentTimeInMiliseconds())
        let store = MixinSignedPreKeyStore()
        _ = store.store(signedPreKey: try record.data(), for: record.id)
        CryptoUserDefault.shared.signedPrekeyOffset = signedPreKeyOffset + 1
        return record
    }

    static func generateKeys() throws -> SignalKeyRequest {
        let identityKeyPair = try PreKeyUtil.getIdentityKeyPair()
        let preKeys = try PreKeyUtil.generatePreKeys()
        let signedPreKey = try PreKeyUtil.generateSignedPreKey(identityKeyPair: identityKeyPair)

        var oneTimePreKeys = [OneTimePreKey]()
        for p in preKeys {
            oneTimePreKeys.append(OneTimePreKey(keyId: p.key, preKey: p.value))
        }
        return SignalKeyRequest(identityKey: identityKeyPair.publicKey.base64EncodedString(),
                                signedPreKey: SignedPreKeyRequest(signed: signedPreKey),
                                oneTimePreKeys: oneTimePreKeys)
    }
}
