import UIKit

class AttachmentEncryptingInputStream: InputStream {
    
    private(set) var key: Data? // available after initialized
    private(set) var digest: Data? // available after closed
    private(set) var contentLength = -1
    
    private let inputStream: InputStream
    private let plainDataSize: Int
    
    private var cryptor: CCCryptorRef!
    private var hmacContext = CCHmacContext()
    private var digestContext = CC_SHA256_CTX()
    private var outputBuffer = Data()
    private var error: Error?
    private var didFinalizedEncryption = false
    
    internal let isLogEnabled: Bool = false
    
    override var delegate: StreamDelegate? {
        get {
            return inputStream.delegate
        }
        set {
            inputStream.delegate = newValue
        }
    }
    
    override var streamStatus: Stream.Status {
        return error != nil ? .error : inputStream.streamStatus
    }
    
    override var streamError: Error? {
        return error ?? inputStream.streamError
    }
    
    override var hasBytesAvailable: Bool {
        let hasBytesAvailable = !didFinalizedEncryption || inputStream.hasBytesAvailable || !outputBuffer.isEmpty
        return hasBytesAvailable
    }
    
    public override init(data: Data) {
        inputStream = InputStream(data: data)
        plainDataSize = data.count
        super.init(data: data)
        prepare()
    }
    
    public override init?(url: URL) {
        guard let fileSize = try? url.resourceValues(forKeys: Set([.fileSizeKey])).fileSize, let stream = InputStream(url: url) else {
            return nil
        }
        plainDataSize = fileSize
        inputStream = stream
        super.init(url: url)
        prepare()
    }
    
    override func open() {
        inputStream.open()
    }
    
    override func close() {
        inputStream.close()
    }
    
    override func property(forKey key: Stream.PropertyKey) -> Any? {
        return inputStream.property(forKey: key)
    }
    
    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        return inputStream.setProperty(property, forKey: key)
    }
    
    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        inputStream.schedule(in: aRunLoop, forMode: mode)
    }
    
    override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        inputStream.remove(from: aRunLoop, forMode: mode)
    }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard outputBuffer.isEmpty else {
            return writeOutputBuffer(to: buffer, maxLength: len)
        }
        while outputBuffer.isEmpty && inputStream.hasBytesAvailable {
            var inputBuffer = Data(count: len)
            inputBuffer.count = inputBuffer.withUnsafeMutableUInt8Pointer {
                inputStream.read($0!, maxLength: len)
            }
            if outputBuffer.count == 0 {
                // withUnsafeMutableBytes crashes for zero-counted Data
                outputBuffer.count = inputBuffer.count
            }
            var outputSize = outputBuffer.count
            var status = outputBuffer.withUnsafeMutableUInt8Pointer {
                CCCryptorUpdate(cryptor, (inputBuffer as NSData).bytes, inputBuffer.count, $0, outputSize, &outputSize)
            }
            if status == .success {
                outputBuffer.count = outputSize
            } else if status == .bufferTooSmall {
                outputSize = CCCryptorGetOutputLength(cryptor, inputBuffer.count, false)
                outputBuffer.count = outputSize
                status = outputBuffer.withUnsafeMutableUInt8Pointer {
                    CCCryptorUpdate(cryptor, (inputBuffer as NSData).bytes, inputBuffer.count, $0, outputSize, &outputSize)
                }
            }
            if status == .success {
                outputBuffer.withUnsafeBytes {
                    CCHmacUpdate(&hmacContext, $0.baseAddress, outputSize)
                    CC_SHA256_Update(&digestContext, $0.baseAddress, CC_LONG(outputSize))
                }
            } else {
                error = AttachmentCryptographyError.encryptorUpdate(status)
            }
        }
        if outputBuffer.isEmpty && !inputStream.hasBytesAvailable {
            finalizeEncryption()
        }
        let numberOfBytesWritten: Int
        if error == nil {
            if !outputBuffer.isEmpty {
                numberOfBytesWritten = writeOutputBuffer(to: buffer, maxLength: len)
            } else {
                numberOfBytesWritten = 0
            }
        } else {
            numberOfBytesWritten = -1
        }
        return numberOfBytesWritten
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
}

extension AttachmentEncryptingInputStream {
    
    private func prepare() {
        do {
            let iv = try AttachmentCryptography.randomData(length: AttachmentCryptography.Length.aesCbcIv)
            let encryptionKey = try AttachmentCryptography.randomData(length: AttachmentCryptography.Length.aesKey)
            let hmacKey = try AttachmentCryptography.randomData(length: AttachmentCryptography.Length.hmac256Key)
            
            cryptor = try CCCryptorRef(operation: .encrypt, algorithm: .aes128, options: .pkcs7Padding, key: encryptionKey, iv: iv)
            
            hmacKey.withUnsafeBytes {
                CCHmacInit(&hmacContext, .sha256, $0.baseAddress, hmacKey.count)
            }
            iv.withUnsafeBytes {
                CCHmacUpdate(&hmacContext, $0.baseAddress, iv.count)
            }
            
            CC_SHA256_Init(&digestContext)
            iv.withUnsafeBytes {
                _ = CC_SHA256_Update(&digestContext, $0.baseAddress, CC_LONG(iv.count))
            }
            
            key = encryptionKey + hmacKey
            outputBuffer = iv
            contentLength = AttachmentCryptography.Length.aesCbcIv
                + CCCryptorGetOutputLength(cryptor, plainDataSize, true)
                + AttachmentCryptography.Length.hmac
        } catch {
            self.error = error
        }
    }
    
    private func finalizeEncryption() {
        var outputSize = CCCryptorGetOutputLength(cryptor, 0, true)
        outputBuffer = Data(count: outputSize)
        let status = outputBuffer.withUnsafeMutableUInt8Pointer {
            CCCryptorFinal(cryptor, $0, outputSize, &outputSize)
        }
        outputBuffer.count = outputSize
        guard status == .success else {
            error = AttachmentCryptographyError.encryptorUpdate(status)
            return
        }
        outputBuffer.withUnsafeBytes {
            CCHmacUpdate(&hmacContext, $0.baseAddress, outputSize)
        }
        var hmac = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        hmac.withUnsafeMutableUInt8Pointer {
            CCHmacFinal(&hmacContext, $0)
        }
        hmac = hmac[0..<AttachmentCryptography.Length.hmac]
        outputBuffer.append(hmac)
        outputSize = outputBuffer.count
        _ = outputBuffer.withUnsafeBytes {
            CC_SHA256_Update(&digestContext, $0.baseAddress, CC_LONG(outputSize))
        }
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = digest.withUnsafeMutableUInt8Pointer {
            CC_SHA256_Final($0, &digestContext)
        }
        self.digest = digest
        didFinalizedEncryption = true
    }
    
    private func writeOutputBuffer(to destination: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        let numberOfBytesToCopy = min(maxLength, outputBuffer.count)
        outputBuffer.copyBytes(to: destination, count: numberOfBytesToCopy)
        let firstUncopiedIndex = outputBuffer.startIndex.advanced(by: numberOfBytesToCopy)
        // withUnsafeMutableBytes crash for data slices before Swift 4.1
        // Use outputBuffer = outputBuffer[firstUncopiedIndex...] after upgraded
        outputBuffer = Data(outputBuffer[firstUncopiedIndex...])
        return numberOfBytesToCopy
    }
    
}
