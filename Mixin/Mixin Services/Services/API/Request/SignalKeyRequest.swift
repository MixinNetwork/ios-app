import Foundation

public struct SignalKeyRequest: Codable {
    
    public let identityKey: String
    public let signedPreKey: SignedPreKeyRequest
    public let oneTimePreKeys: [OneTimePreKey]?
    
    enum CodingKeys: String, CodingKey {
        case identityKey = "identity_key"
        case signedPreKey = "signed_pre_key"
        case oneTimePreKeys = "one_time_pre_keys"
    }
    
}

public struct OneTimePreKey: Codable {
    
    public let key_id: UInt32
    public let pub_key: String
    
    public init(keyId: UInt32, preKey: SessionPreKey) {
        key_id = keyId
        pub_key = preKey.keyPair.publicKey.base64EncodedString()
    }
    
}

public struct SignedPreKeyRequest: Codable {
    
    public let key_id: UInt32
    public let pub_key: String
    public var signature: String
    
    public init(signed: SessionSignedPreKey) {
        key_id = signed.id
        pub_key = signed.keyPair.publicKey.base64EncodedString()
        signature = signed.signature.base64EncodedString()
    }
    
}
