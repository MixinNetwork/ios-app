import Foundation
import CommonCrypto

public struct HMACSHA256 {
    
    public static let digestDataCount = Int(CC_SHA256_DIGEST_LENGTH)
    
    private var context = CCHmacContext()
    
    public init(key: Data) {
        key.withUnsafeBytes { key in
            CCHmacInit(&context, .sha256, key.baseAddress, key.count)
        }
    }
    
    public mutating func update(data input: Data) {
        input.withUnsafeBytes { input in
            CCHmacUpdate(&context, input.baseAddress, input.count)
        }
    }
    
    public mutating func finalize() -> Data {
        let result = malloc(Self.digestDataCount)!
        CCHmacFinal(&context, result)
        return Data(bytesNoCopy: result, count: Self.digestDataCount, deallocator: .free)
    }
    
}

extension HMACSHA256 {
    
    public static func mac(for input: Data, using key: Data) -> Data {
        let mac = malloc(digestDataCount)!
        input.withUnsafeBytes { input in
            key.withUnsafeBytes { key in
                CCHmac(.sha256, key.baseAddress, key.count, input.baseAddress, input.count, mac)
            }
        }
        return Data(bytesNoCopy: mac, count: digestDataCount, deallocator: .free)
    }
    
}
