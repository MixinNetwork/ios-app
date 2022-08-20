import Foundation
import CommonCrypto

public enum EncryptedProtocol {
    
    enum Error: Swift.Error {
        case unsupportedVersion
        case invalidPlatform // sizeof(UInt16) != 2
        case invalidPublicKey
        case invalidEncryptedKey
        case keyGeneration
        case ivGeneration
        case agreementCalculation
        case invalidAgreement
        case badCipher
        case noSessionIdMatches
    }
    
    public static func encrypt(
        _ message: Data,
        with privateKey: Ed25519PrivateKey,
        remotePublicKey: Data,
        remoteSessionID: UUID,
        extensionSession: (id: UUID, key: Data)?
    ) throws -> Data {
        guard MemoryLayout<SessionCount>.size == Length.sessionCount else {
            throw Error.invalidPlatform
        }
        guard let key = Data(withNumberOfSecuredRandomBytes: Length.key) else {
            throw Error.keyGeneration
        }
        guard let iv = Data(withNumberOfSecuredRandomBytes: Length.messageIV) else {
            throw Error.ivGeneration
        }
        let senderPublicKey = privateKey.publicKey.x25519Representation
        guard senderPublicKey.count == Length.publicKey else {
            throw Error.invalidPublicKey
        }
        let encryptedKey = try encrypt(messageKey: key, privateKey: privateKey, remotePublicKey: remotePublicKey)
        guard encryptedKey.count == Length.keyIV + Length.encryptedKey else {
            throw Error.invalidEncryptedKey
        }
        let encryptedMessage = try AESGCMCryptor.encrypt(message, with: key, iv: iv)
        if let extensionSession = extensionSession, extensionSession.key.count == Length.publicKey {
            let encryptedExtensionMessageKey = try encrypt(messageKey: key, privateKey: privateKey, remotePublicKey: extensionSession.key)
            let cipher = Data([Self.version])
                + numberOfSessions(2)
                + senderPublicKey
                + extensionSession.id.data
                + encryptedExtensionMessageKey
                + remoteSessionID.data
                + encryptedKey
                + iv
                + encryptedMessage
            return cipher
        } else {
            let cipher = Data([Self.version])
                + numberOfSessions(1)
                + senderPublicKey
                + remoteSessionID.data
                + encryptedKey
                + iv
                + encryptedMessage
            return cipher
        }
    }
    
    public static func decrypt(cipher: Data, with privateKey: Ed25519PrivateKey, sessionId: UUID) throws -> Data {
        guard MemoryLayout<SessionCount>.size == Length.sessionCount else {
            throw Error.invalidPlatform
        }
        guard cipher.count > Length.version + Length.sessionCount else {
            throw Error.badCipher
        }
        guard cipher[cipher.startIndex] == Self.version else {
            throw Error.unsupportedVersion
        }
        
        func cipherSlice(start: Int, count: Int? = nil) -> Data {
            if let count = count {
                return cipher[cipher.startIndex.advanced(by: start)...cipher.startIndex.advanced(by: start + count - 1)]
            } else {
                return cipher[cipher.startIndex.advanced(by: start)...]
            }
        }
        
        let numberOfSessions = numberOfSessions(cipherSlice(start: Length.version, count: Length.sessionCount))
        guard cipher.count > Length.version + Length.sessionCount + Length.publicKey + Int(numberOfSessions) * Length.sessionInfo else {
            throw Error.badCipher
        }
        
        let mySessionIdData = sessionId.data
        let maybeSessionIndex = (0..<numberOfSessions).first { (index) -> Bool in
            let offset = Length.version + Length.sessionCount + Length.publicKey + Int(index) * Length.sessionInfo
            let sid = cipherSlice(start: offset, count: Length.sessionId)
            return sid == mySessionIdData
        }
        guard let sessionIndex = maybeSessionIndex else {
            throw Error.noSessionIdMatches
        }
        
        let senderPublicKey = cipherSlice(start: Length.version + Length.sessionCount, count: Length.publicKey)
        
        let sessionOffset = Length.version + Length.sessionCount + Length.publicKey + Int(sessionIndex) * Length.sessionInfo
        let keyIV = cipherSlice(start: sessionOffset + Length.sessionId, count: Length.keyIV)
        let encryptedKey = cipherSlice(start: sessionOffset + Length.sessionId + Length.keyIV, count: Length.encryptedKey)
        
        let messageOffset = Length.version + Length.sessionCount + Length.publicKey + Int(numberOfSessions) * Length.sessionInfo
        let messageIV = cipherSlice(start: messageOffset, count: Length.messageIV)
        let encryptedMessage = cipherSlice(start: messageOffset + Length.messageIV)
        
        let key = try decrypt(messageKey: encryptedKey, iv: keyIV, privateKey: privateKey, remotePublicKey: senderPublicKey)
        let decryptedMessage = try AESGCMCryptor.decrypt(encryptedMessage, with: key, iv: messageIV)
        return decryptedMessage
    }
    
}

extension EncryptedProtocol {
    
    private enum Length {
        static let version = 1
        static let sessionCount = 2
        static let publicKey = 32
        static let sessionId = 16
        static let key = kCCKeySizeAES128 // 16
        static let messageIV = 12
        static let keyIV = AESCryptor.ivSize
        static let encryptedKey = 32
        static let sessionInfo = sessionId + keyIV + encryptedKey
    }
    
    private typealias SessionCount = UInt16
    
    private static let version: UInt8 = 0x01
    
    private static func numberOfSessions(_ input: Data) -> SessionCount {
        guard input.count == Length.sessionCount else {
            return 0
        }
        var output: SessionCount = 0
        withUnsafeMutableBytes(of: &output) { outputPtr in
            input.withUnsafeBytes { inputPtr in
                inputPtr.copyBytes(to: outputPtr)
            }
        }
        return SessionCount(littleEndian: output)
    }
    
    private static func numberOfSessions(_ count: SessionCount) -> Data {
        count.data(endianness: .little)
    }
    
    // Returns IV + Cipher
    private static func encrypt(messageKey: Data, privateKey: Ed25519PrivateKey, remotePublicKey: Data) throws -> Data {
        guard let sharedSecret = AgreementCalculator.agreement(publicKey: remotePublicKey, privateKey: privateKey.x25519Representation) else {
            throw Error.agreementCalculation
        }
        return try AESCryptor.encrypt(messageKey, with: sharedSecret)
    }
    
    private static func decrypt(messageKey cipher: Data, iv: Data, privateKey: Ed25519PrivateKey, remotePublicKey: Data) throws -> Data {
        guard let sharedSecret = AgreementCalculator.agreement(publicKey: remotePublicKey, privateKey: privateKey.x25519Representation) else {
            throw Error.invalidAgreement
        }
        return try AESCryptor.decrypt(cipher, with: sharedSecret, iv: iv)
    }
    
}
