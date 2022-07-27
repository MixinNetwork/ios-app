import Foundation
import CommonCrypto

public enum AESCryptor {
    
    enum Error: Swift.Error {
        case badInput
        case generateIV
        case createCryptor(CCStatus)
        case update(CCStatus)
        case finalize(CCStatus)
    }
    
    static let blockSize = kCCBlockSizeAES128
    static let ivSize = 16
    
    // Encrypts plainData with `key` and a 16 bytes auto-generated IV
    // The IV is prepended to encrypted data
    // Will perform PKCS#7 padding by default
    public static func encrypt(_ plainData: Data, with key: Data) throws -> Data {
        guard let iv = Data(withNumberOfSecuredRandomBytes: ivSize) else {
            throw Error.generateIV
        }
        let encrypted = try crypt(input: plainData,
                                  operation: CCOperation(kCCEncrypt),
                                  key: key,
                                  iv: iv)
        return iv + encrypted
    }
    
    // Will perform PKCS#7 unpadding by default
    public static func decrypt(_ cipher: Data, with key: Data, iv: Data) throws -> Data {
        try crypt(input: cipher,
                  operation: CCOperation(kCCDecrypt),
                  key: key,
                  iv: iv)
    }
    
    // IV should be prepended to encrypted data
    // Will perform PKCS#7 unpadding by default
    public static func decrypt(_ ivPlusCipher: Data, with key: Data) throws -> Data {
        guard ivPlusCipher.count > ivSize else {
            throw Error.badInput
        }
        return try crypt(input: ivPlusCipher[ivSize...],
                         operation: CCOperation(kCCDecrypt),
                         key: key,
                         iv: ivPlusCipher[0..<ivSize])
    }
    
    private static func crypt(input: Data, operation: CCOperation, key: Data, iv: Data) throws -> Data {
        var cryptor: CCCryptorRef! = nil
        var status = key.withUnsafeBytes { keyBuffer in
            iv.withUnsafeBytes { ivBuffer in
                CCCryptorCreate(operation,
                                CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                keyBuffer.baseAddress,
                                keyBuffer.count,
                                ivBuffer.baseAddress,
                                &cryptor)
            }
        }
        guard status == kCCSuccess else {
            throw Error.createCryptor(status)
        }
        
        let outputBufferSize = CCCryptorGetOutputLength(cryptor, input.count, true)
        let output = malloc(outputBufferSize)!
        
        var dataOutMoved: size_t = 0
        var outputCount = 0
        
        status = input.withUnsafeBytes { inputBuffer in
            CCCryptorUpdate(cryptor,
                            inputBuffer.baseAddress,
                            inputBuffer.count,
                            output,
                            outputBufferSize,
                            &dataOutMoved)
        }
        guard status == kCCSuccess else {
            CCCryptorRelease(cryptor)
            free(output)
            throw Error.update(status)
        }
        outputCount += dataOutMoved
        
        status = CCCryptorFinal(cryptor,
                                output.advanced(by: dataOutMoved),
                                outputBufferSize - dataOutMoved,
                                &dataOutMoved)
        guard status == kCCSuccess else {
            CCCryptorRelease(cryptor)
            free(output)
            throw Error.finalize(status)
        }
        outputCount += dataOutMoved
        
        CCCryptorRelease(cryptor)
        return Data(bytesNoCopy: output, count: outputCount, deallocator: .free)
    }
    
}

