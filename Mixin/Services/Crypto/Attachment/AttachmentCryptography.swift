import Foundation

enum AttachmentCryptographyError: Error {
    case keyGeneration(OSStatus)
    case cryptorCreate(CCStatus)
    case encryptorUpdate(CCStatus)
    case encryptorFinal(CCStatus)
    case decryptorUpdate(CCStatus)
    case decryptorFinal(CCStatus)
    case hmacInconsistency
    case digestInconsistency
    case unexpectedEnding
}

struct AttachmentCryptography {
    
    static func randomData(length: Int) throws -> Data {
        var data = Data(count: length)
        var status: OSStatus = errSecSuccess
        data.withUnsafeMutableBytes {
            status = SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
        }
        if status == errSecSuccess {
            return data
        } else {
            throw AttachmentCryptographyError.keyGeneration(status)
        }
    }
    
    struct Length {
        static let hmac256Key = 32
        static let aesKey = 32
        static let aesCbcIv = 16
        static let hmac = 32
        static let digest = 32
    }
    
}

extension CCCryptorRef {
    
    init(operation: CCOperation, algorithm: CCAlgorithm, options: CCOptions, key: Data, iv: Data) throws {
        var cryptor: CCCryptorRef? = nil
        let status = CCCryptorCreate(operation, algorithm, options, (key as NSData).bytes, key.count, (iv as NSData).bytes, &cryptor)
        if status == .success, let cryptor = cryptor {
            self = cryptor
        } else {
            throw AttachmentCryptographyError.cryptorCreate(status)
        }
    }
    
}

extension CCOperation {
    static let encrypt = CCOperation(kCCEncrypt)
    static let decrypt = CCOperation(kCCDecrypt)
}

extension CCAlgorithm {
    static let aes128 = CCAlgorithm(kCCAlgorithmAES128)
}

extension CCOptions {
    static let pkcs7Padding = CCOptions(kCCOptionPKCS7Padding)
}

extension CCHmacAlgorithm {
    static let sha256 = CCHmacAlgorithm(kCCHmacAlgSHA256)
}

extension CCStatus {
    static let unspecifiedError = CCStatus(kCCUnspecifiedError)
    static let bufferTooSmall = CCStatus(kCCBufferTooSmall)
    static let success = CCStatus(kCCSuccess)
}
