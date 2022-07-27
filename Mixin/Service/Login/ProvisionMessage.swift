import Foundation
import CommonCrypto
import MixinServices
import libsignal_protocol_c

struct ProvisionMessage: Encodable {
    
    let identityKeyPublic: Data
    let identityKeyPrivate: Data
    let userId: String
    let sessionId: String
    let provisioningCode: String
    let platform = "iOS"
    
    init(identityKeyPublic: Data, identityKeyPrivate: Data, userId: String, sessionId: String, provisioningCode: String) {
        self.identityKeyPublic = identityKeyPublic
        self.identityKeyPrivate = identityKeyPrivate
        self.userId = userId
        self.sessionId = sessionId
        self.provisioningCode = provisioningCode
    }
    
}

extension ProvisionMessage {
    
    enum EncryptError: Error {
        case invalidPublicKey(Int32?)
        case generateKeyPair(Int32)
        case createHKDF(Int32)
        case calculateAgreement(Int32)
        case deriveSecret(Int)
        case serializePublicKey(Int32)
    }
    
    private enum Length {
        static let messageEncryptKey = 32
        static let hmacKey = 32
        static let version = MemoryLayout<Version>.size
    }
    
    private typealias Version = UInt8
    
    private static let version: Version = 1
    
    func encrypt(with base64EncodedPublicKey: String) throws -> Data {
        guard let key = Data(base64Encoded: base64EncodedPublicKey) else {
            throw EncryptError.invalidPublicKey(nil)
        }
        
        var remotePublicKey: OpaquePointer!
        var status = key.withUnsafeBytes { key in
            curve_decode_point(&remotePublicKey, key.baseAddress, key.count, globalSignalContext)
        }
        guard status == 0 else {
            throw EncryptError.invalidPublicKey(status)
        }
        
        let messageJSONData = try JSONEncoder.snakeCase.encode(self)
        
        var keyPair: OpaquePointer!
        var sharedSecret: UnsafeMutablePointer<UInt8>!
        var hkdf: OpaquePointer!
        var derivedSecret: UnsafeMutablePointer<UInt8>!
        defer {
            ec_key_pair_destroy(keyPair)
            free(sharedSecret)
            hkdf_destroy(hkdf)
            free(derivedSecret)
        }
        
        status = curve_generate_key_pair(globalSignalContext, &keyPair)
        guard status == 0 else {
            throw EncryptError.generateKeyPair(status)
        }
        
        let localPublicKey = ec_key_pair_get_public(keyPair)
        let localPrivateKey = ec_key_pair_get_private(keyPair)
        
        let sharedSecretLength = curve_calculate_agreement(&sharedSecret, remotePublicKey, localPrivateKey)
        guard sharedSecretLength > 0 else {
            throw EncryptError.calculateAgreement(sharedSecretLength)
        }
        
        status = hkdf_create(&hkdf, 3, globalSignalContext)
        guard status == 0 else {
            throw EncryptError.createHKDF(status)
        }
        
        let salt = Data(count: 32)
        let info = "Mixin Provisioning Message".data(using: .utf8)!
        let derivedSecretLength = salt.withUnsafeBytes { salt in
            info.withUnsafeBytes { info in
                hkdf_derive_secrets(hkdf,
                                    &derivedSecret,
                                    sharedSecret,
                                    Int(sharedSecretLength),
                                    salt.baseAddress,
                                    salt.count,
                                    info.baseAddress,
                                    info.count,
                                    Length.messageEncryptKey + Length.hmacKey)
            }
        }
        guard derivedSecretLength >= 0 else {
            throw EncryptError.deriveSecret(derivedSecretLength)
        }
        let messageEncryptKey = Data(bytesNoCopy: derivedSecret, count: Length.messageEncryptKey, deallocator: .none)
        let hmacKey = derivedSecret.advanced(by: Length.messageEncryptKey)
        
        let encryptedMessage = try AESCryptor.encrypt(messageJSONData, with: messageEncryptKey)
        let bodyLength = Length.version + encryptedMessage.count + Int(CC_SHA256_DIGEST_LENGTH)
        var body = Data(capacity: bodyLength)
        body.append(Self.version)
        body.append(encryptedMessage)
        
        let hmacCount = Int(CC_SHA256_DIGEST_LENGTH)
        let hmac = malloc(hmacCount).assumingMemoryBound(to: UInt8.self)
        body.withUnsafeBytes { body in
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                   hmacKey,
                   Length.hmacKey,
                   body.baseAddress,
                   body.count,
                   hmac)
        }
        body.append(UnsafeBufferPointer(start: hmac, count: hmacCount))
        free(hmac)
        
        var buffer: OpaquePointer!
        status = ec_public_key_serialize(&buffer, localPublicKey)
        guard status == 0 else {
            throw EncryptError.serializePublicKey(status)
        }
        let serializedPublicKey = Data(bytes: signal_buffer_data(buffer),
                                       count: signal_buffer_len(buffer))
        signal_buffer_free(buffer)
        
        let envelope = [
            "public_key": serializedPublicKey.base64EncodedString(),
            "body": body.base64EncodedString()
        ]
        return try JSONSerialization.data(withJSONObject: envelope, options: [])
    }
    
}
