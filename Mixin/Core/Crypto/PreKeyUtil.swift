import Foundation

class PreKeyUtil {

    static let LOCAL_REGISTRATION_ID = "local_registration_id"
    static let BATCH_SIZE: Int = 700
    static let prekeyMiniNum = 500

    static func generatePreKeys() throws -> [OneTimePreKey] {
        let preKeyIdOffset = CryptoUserDefault.shared.prekeyOffset
        let records = try Signal.generatePreKeys(start: preKeyIdOffset, count: BATCH_SIZE)
        CryptoUserDefault.shared.prekeyOffset = preKeyIdOffset + UInt32(BATCH_SIZE) + 1
        let preKeys = try records.map { PreKey(preKeyId: Int($0.id), record: try $0.data()) }
        MixinPreKeyStore().store(preKeys: preKeys)
        return records.map { OneTimePreKey(keyId: $0.id, preKey: $0) }
    }

    static func getIdentityKeyPair() throws -> KeyPair {
        guard let identity = IdentityDAO.shared.getLocalIdentity() else {
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
        let oneTimePreKeys = try PreKeyUtil.generatePreKeys()
        let signedPreKey = try PreKeyUtil.generateSignedPreKey(identityKeyPair: identityKeyPair)
        return SignalKeyRequest(identityKey: identityKeyPair.publicKey.base64EncodedString(),
                                signedPreKey: SignedPreKeyRequest(signed: signedPreKey),
                                oneTimePreKeys: oneTimePreKeys)
    }
}
