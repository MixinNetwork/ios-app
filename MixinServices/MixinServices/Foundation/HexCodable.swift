import Foundation
import CryptoKit

// - MARK: Decode
extension Data {
    
    public init?<String: StringProtocol>(hexEncodedString: String) {
        let (numberOfBytes, remainder) = hexEncodedString.count.quotientAndRemainder(dividingBy: 2)
        guard numberOfBytes > 0, remainder == 0 else {
            return nil
        }
        self.init(capacity: numberOfBytes)
        var index = hexEncodedString.startIndex
        while index < hexEncodedString.endIndex {
            let endIndex = hexEncodedString.index(index, offsetBy: 2)
            let number = hexEncodedString[index..<endIndex]
            if let byte = UInt8(number, radix: 16) {
                append(byte)
            } else {
                return nil
            }
            index = endIndex
        }
    }
    
}

// - MARK: Encode
fileprivate let hexAlphabets = "0123456789abcdef"
fileprivate let utf16HexDigits = Array(hexAlphabets.utf16)
fileprivate let utf8HexDigits = Array(hexAlphabets.utf8)

extension UInt8 {
    
    func hexEncodedUnichars() -> (unichar, unichar) {
        let (high, low) = self.quotientAndRemainder(dividingBy: 16)
        return (utf16HexDigits[Int(high)], utf16HexDigits[Int(low)])
    }
    
}

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
        String(unsafeUninitializedCapacity: 2 * self.count) { (buffer) -> Int in
            var p = buffer.baseAddress!
            for byte in self {
                let (high, low) = byte.quotientAndRemainder(dividingBy: 16)
                p[0] = utf8HexDigits[Int(high)]
                p[1] = utf8HexDigits[Int(low)]
                p += 2
            }
            return 2 * self.count
        }
    }
    
}
