import Foundation
import CryptoKit

extension Data: HexEncodable {
    
}

extension SHA256Digest: HexEncodable {
    
    public var count: Int {
        Self.byteCount
    }
    
}

public protocol HexEncodable: Sequence where Self.Element == UInt8 {
    var count: Int { get }
}

extension HexEncodable {
    
    public func hexEncodedString() -> String {
        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
            let digits = Array("0123456789abcdef".utf8)
            return String(unsafeUninitializedCapacity: 2 * self.count) { (buffer) -> Int in
                var p = buffer.baseAddress!
                for byte in self {
                    p[0] = digits[Int(byte / 16)]
                    p[1] = digits[Int(byte % 16)]
                    p += 2
                }
                return 2 * self.count
            }
        } else {
            var chars: [unichar] = []
            chars.reserveCapacity(2 * self.count)
            for byte in self {
                let (high, low) = byte.hexEncodedUnichars()
                chars.append(high)
                chars.append(low)
            }
            return String(utf16CodeUnits: chars, count: chars.count)
        }
    }
    
}
