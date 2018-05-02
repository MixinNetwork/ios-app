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
    
    static func randomData(length: Length) throws -> Data {
        let length = length.value
        var data = Data(count: length)
        var status: OSStatus = errSecSuccess
        data.withUnsafeMutableBytes {
            status = SecRandomCopyBytes(kSecRandomDefault, length, $0)
        }
        if status == errSecSuccess {
            return data
        } else {
            throw AttachmentCryptographyError.keyGeneration(status)
        }
    }
    
    enum Length {
        case hmac256Key
        case aesKey
        case aesCbcIv
        
        case hmac
        case digest

        var value: Int {
            switch self {
            case .hmac256Key, .aesKey, .hmac, .digest:
                return 32
            case .aesCbcIv:
                return 16
            }
        }
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
