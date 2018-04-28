import Foundation

struct SignalKeyRequest: Codable {

    let identityKey: String
    let signedPreKey: SignedPreKeyRequest
    let oneTimePreKeys: [OneTimePreKey]?

    enum CodingKeys: String, CodingKey {
        case identityKey = "identity_key"
        case signedPreKey = "signed_pre_key"
        case oneTimePreKeys = "one_time_pre_keys"
    }

}

struct OneTimePreKey: Codable {
    let key_id: UInt32
    let pub_key: String

    init(keyId: UInt32, preKey: SessionPreKey) {
        key_id = keyId
        pub_key = preKey.keyPair.publicKey.base64EncodedString()
    }
}

struct SignedPreKeyRequest: Codable {
    let key_id: UInt32
    let pub_key: String
    var signature: String

    init(signed: SessionSignedPreKey) {
        key_id = signed.id
        pub_key = signed.keyPair.publicKey.base64EncodedString()
        signature = signed.signature.base64EncodedString()
    }
}
