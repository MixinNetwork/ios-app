import Foundation
import CommonCrypto

public final class AESCryptor {
    
    enum Error: Swift.Error {
        case badInput
        case generateIV
        case createCryptor(CCStatus)
        case update(CCStatus)
        case finalize(CCStatus)
    }
    
    static let ivSize = 16
    
    private let cryptor: CCCryptorRef
    
    private var buffer: Data
    
    public init(operation: CCOperation, iv: Data, key: Data) throws {
        var cryptor: CCCryptorRef! = nil
        let status = key.withUnsafeBytes { key in
            iv.withUnsafeBytes { iv in
                return CCCryptorCreate(operation,
                                       CCAlgorithm(kCCAlgorithmAES),
                                       CCOptions(kCCOptionPKCS7Padding),
                                       key.baseAddress,
                                       key.count,
                                       iv.baseAddress,
                                       &cryptor)
            }
        }
        guard status == kCCSuccess else {
            throw Error.createCryptor(status)
        }
        self.cryptor = cryptor
        self.buffer = Data()
    }
    
    deinit {
        CCCryptorRelease(cryptor)
    }
    
    public func outputDataCount(inputDataCount: Int, isFinal: Bool) -> Int {
        CCCryptorGetOutputLength(cryptor, inputDataCount, isFinal)
    }
    
    public func reserveOutputBufferCapacity(_ capacity: Int) {
        buffer.reserveCapacity(capacity)
    }
    
    public func update(_ input: Data) throws -> Data {
        let outputSize = CCCryptorGetOutputLength(cryptor, input.count, false)
        if outputSize > buffer.count {
            buffer.count = outputSize
        }
        
        var dataOutMoved: Int = 0
        let status = input.withUnsafeBytes { input in
            buffer.withUnsafeMutableBytes { buffer in
                CCCryptorUpdate(cryptor,
                                input.baseAddress,
                                input.count,
                                buffer.baseAddress,
                                buffer.count,
                                &dataOutMoved)
            }
        }
        guard status == kCCSuccess else {
            throw Error.update(status)
        }
        
        if dataOutMoved == 0 {
            return Data()
        } else {
            return buffer.prefix(dataOutMoved)
        }
    }
    
    public func finalize() throws -> Data {
        let outputSize = CCCryptorGetOutputLength(cryptor, 0, true)
        buffer.count = outputSize
        var dataOutMoved: Int = 0
        let status = buffer.withUnsafeMutableBytes { buffer in
            CCCryptorFinal(cryptor,
                           buffer.baseAddress,
                           buffer.count,
                           &dataOutMoved)
        }
        guard status == kCCSuccess else {
            throw Error.finalize(status)
        }
        return buffer.prefix(dataOutMoved)
    }
    
}

// MARK: - Stateless Operations
extension AESCryptor {
    
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
        let firstCipherIndex = ivPlusCipher.startIndex.advanced(by: ivSize)
        return try crypt(input: ivPlusCipher[firstCipherIndex...],
                         operation: CCOperation(kCCDecrypt),
                         key: key,
                         iv: ivPlusCipher[..<firstCipherIndex])
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

