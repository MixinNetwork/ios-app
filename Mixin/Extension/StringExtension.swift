import UIKit
import Goutils
import CoreText

extension String {

    func md5() -> String {
        guard let messageData = data(using: .utf8) else {
            return self
        }
        var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))

        _ = digestData.withUnsafeMutableBytes { digestBytes in
            messageData.withUnsafeBytes({ messageBytes in
                CC_MD5(messageBytes, CC_LONG(messageData.count), digestBytes)
            })
        }

        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }

    func sha256() -> String {
        guard let data = data(using: .utf8) else {
            return self
        }
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))

        _ = data.withUnsafeBytes {
            _ = CC_SHA256($0, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    func substring(endChar: Character) -> String {
        guard let endIndex = self.index(of: endChar) else {
            return self
        }
        return String(self[..<endIndex])
    }

    func toUTCDate() -> Date {
        return DateFormatter.iso8601Full.date(from: self) ?? Date()
    }

    func toUUID() -> String {
        var digestData = self.utf8.md5.data

        digestData[6] &= 0x0f       // clear version
        digestData[6] |= 0x30       // set to version 3
        digestData[8] &= 0x3f       // clear variant
        digestData[8] |= 0x80       // set to IETF variant
        var error: NSError?
        return GoutilsUuidFromBytes(digestData, &error)
    }

    subscript (i: Int) -> String {
        guard i < count else {
            return ""
        }
        let startIndex = self.index(self.startIndex, offsetBy: i)
        let endIndex = self.index(startIndex, offsetBy: i + 1)
        return String(self[startIndex ..< endIndex])
    }

    func isNumeric() -> Bool {
        return Double(self) != nil
    }

    public func toInt() -> Int {
        return (self as NSString).integerValue
    }

    public func toInt32() -> Int32 {
        return (self as NSString).intValue
    }

    public func toDouble() -> Double {
        return (self as NSString).doubleValue
    }
    
    func removeWhiteSpaces() -> String {
        let nsStr = self as NSString
        let fullRange = NSRange(location: 0, length: nsStr.length)
        return nsStr.replacingOccurrences(of: "\\s", with: "", options: .regularExpression, range: fullRange)
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

    func toSimpleKey() -> String {
        guard self.count > 10 else {
            return self
        }
        let startString = self[..<self.index(self.startIndex, offsetBy: 6)]
        let endString = self[self.index(self.endIndex, offsetBy: -4)...]
        return "\(startString)...\(endString)"
    }

    func formatSimpleBalance() -> String {
        guard !hasPrefix("0."), let dotIdx = index(of: ".") else {
            return self
        }
        let formatter = NumberFormatter(numberStyle: .decimal, maximumFractionDigits: 8)
        formatter.maximumFractionDigits = 8 - dotIdx.encodedOffset
        return formatter.string(from: NSDecimalNumber(string: self)) ?? self
    }

    func formatFullBalance() -> String {
        return NumberFormatter.balanceFormatter.string(from: NSDecimalNumber(string: self)) ?? self
    }
}

extension NSAttributedStringKey {
    static let ctFont = kCTFontAttributeName as NSAttributedStringKey
    static let ctForegroundColor = kCTForegroundColorAttributeName as NSAttributedStringKey
    static let ctParagraphStyle = kCTParagraphStyleAttributeName as NSAttributedStringKey
}

extension NSMutableAttributedString {
    
    func setCTForegroundColor(_ color: UIColor, for range: NSRange) {
        removeAttribute(.ctForegroundColor, range: range)
        addAttributes([.ctForegroundColor: color.cgColor], range: range)
    }
    
}

