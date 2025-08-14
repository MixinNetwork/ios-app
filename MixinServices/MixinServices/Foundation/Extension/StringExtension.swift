import UIKit
import CommonCrypto
import CoreText

public extension String {

    private static var hashCodeMaps = SafeDictionary<String, Int>()
    
    var isDigitsOnly: Bool {
        range(of: "^[0-9]*$", options: .regularExpression) != nil
    }
    
    var isGenericNumber: Bool {
        let number = NumberFormatter.usLocalizedDecimal.number(from: self)
        return number != nil
    }
    
    var isNumeric: Bool {
        let number = NumberFormatter.decimal.number(from: self)
        return number != nil
    }
    
    var hasMinusPrefix: Bool {
        return hasPrefix("-")
    }
    
    var integerValue: Int {
        return Int(self) ?? 0
    }
    
    var doubleValue: Double {
        return Double(self)
            ?? NumberFormatter.decimal.number(from: self)?.doubleValue
            ?? 0
    }

    var intValue: Int? {
        return Int(self) ?? NumberFormatter.decimal.number(from: self)?.intValue
    }

    var int64Value: Int64? {
        return Int64(self) ?? NumberFormatter.decimal.number(from: self)?.int64Value
    }

    var sqlEscaped: String {
        return replacingOccurrences(of: "/", with: "//")
            .replacingOccurrences(of: "%", with: "/%")
            .replacingOccurrences(of: "_", with: "/_")
            .replacingOccurrences(of: "[", with: "/[")
            .replacingOccurrences(of: "]", with: "/]")
    }
    
    var sha1: String? {
        guard let data = self.data(using: .utf8) else {
            return nil
        }
        var digest = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { (data: UnsafeRawBufferPointer) -> Void in
            digest.withUnsafeMutableUInt8Pointer { (digest) -> Void in
                CC_SHA1(data.baseAddress, CC_LONG(data.count), digest)
            }
        }
        return digest.hexEncodedString()
    }
    
    func uuidDigest() -> String {
        UUID.uniqueObjectIDString(self)
    }
    
    func md5() -> String {
        guard let messageData = data(using: .utf8) else {
            return self
        }
        var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))

        _ = digestData.withUnsafeMutableUInt8Pointer { digestBytes in
            messageData.withUnsafeBytes({ messageBytes in
                CC_MD5(messageBytes.baseAddress, CC_LONG(messageData.count), digestBytes)
            })
        }

        return digestData.hexEncodedString()
    }
    
    func substring(endChar: Character) -> String {
        guard let endIndex = self.firstIndex(of: endChar) else {
            return self
        }
        return String(self[..<endIndex])
    }

    func suffix(char: Character) -> String? {
        guard let suffixIndex = firstIndex(of: char) else {
            return nil
        }
        return String(suffix(from: index(suffixIndex, offsetBy: 1)))
    }
    
    func toUTCDate() -> Date {
        return DateFormatter.iso8601Full.date(from: self) ?? Date()
    }
    
    func positiveHashCode() -> Int {
        if let code = String.hashCodeMaps[self] {
            return code
        }
        let code = Int(abs(hashCode()))
        String.hashCodeMaps[self] = code
        return code
    }

    func hashCode() -> Int32 {
        let components = self.split(separator: "-")
        guard components.count >= 5 else {
            return 0
        }

        var mostSigBits = Int64(components[0], radix: 16)!
        mostSigBits <<= 16

        let c1 = Int64(components[1], radix: 16)!
        mostSigBits |= c1
        mostSigBits <<= 16
        let c2 = Int64(components[2], radix: 16)!
        mostSigBits |= c2

        var leastSigBits = Int64(components[3], radix: 16)!
        leastSigBits <<= 48
        let c4 = Int64(components[4], radix: 16)!
        leastSigBits |= c4

        let hilo = mostSigBits ^ leastSigBits

        return Int32(truncatingIfNeeded: hilo>>32) ^ Int32(truncatingIfNeeded: hilo)
    }

    subscript (i: Int) -> String {
        guard i < count else {
            return ""
        }
        let startIndex = self.index(self.startIndex, offsetBy: i)
        let endIndex = self.index(startIndex, offsetBy: i + 1)
        return String(self[startIndex ..< endIndex])
    }
    
    func removeWhiteSpaces() -> String {
        let nsStr = self as NSString
        let fullRange = NSRange(location: 0, length: nsStr.length)
        return nsStr.replacingOccurrences(of: "\\s", with: "", options: .regularExpression, range: fullRange)
    }

    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func digits() -> String {
        return components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    func isInteger() -> Bool {
        return self == digits()
    }

    func base64Encoded() -> String? {
        if let data = self.data(using: .utf8) {
            return data.base64EncodedString()
        }
        return nil
    }

    func base64Decoded() -> String? {
        if let data = Data(base64Encoded: self) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
}

public extension Optional where Wrapped == String {
    
    var isNilOrEmpty: Bool {
        switch self {
        case .some(let value):
            return value.isEmpty
        case .none:
            return true
        }
    }

    var uuidString: String? {
        guard let value = self, UUID(uuidString: value) != nil else {
            return nil
        }
        return value
    }
}

extension Substring {

    func dropFirstAndLast() -> String {
        let text = String(self)
        let start = text.index(text.startIndex, offsetBy: 1)
        let end = text.index(text.endIndex, offsetBy: -1)
        return String(text[start..<end])
    }

}
