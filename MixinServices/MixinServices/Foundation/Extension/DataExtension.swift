import Foundation

public extension Data {
    
    var bytes : [UInt8] {
        return [UInt8](self)
    }
    
    init?(withNumberOfSecuredRandomBytes count: Int) {
        guard let bytes = malloc(count) else {
            return nil
        }
        let status = SecRandomCopyBytes(kSecRandomDefault, count, bytes)
        guard status == errSecSuccess else {
            return nil
        }
        self.init(bytesNoCopy: bytes, count: count, deallocator: .free)
    }
    
    init?<S: StringProtocol>(base64URLEncoded string: S) {
        var str = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = string.count % 4
        if remainder != 0 {
            str.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: str)
    }
    
    func toString() -> String {
        return String(data: self, encoding: .utf8)!
    }
    
    // Avoid potential timing attacks
    func isEqualToDataInConstantTime(_ another: Data) -> Bool {
        guard self.count == another.count else {
            return false
        }
        var isEqual = true
        for i in 0..<count {
            isEqual = isEqual && (self[i] == another[i])
        }
        return isEqual
    }
    
    func base64RawURLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    @inlinable func withUnsafeUInt8Pointer<ResultType>(_ body: (UnsafePointer<UInt8>?) throws -> ResultType) rethrows -> ResultType {
        return try withUnsafeBytes({ (buffer) -> ResultType in
            let ptr = buffer.bindMemory(to: UInt8.self).baseAddress
            return try body(ptr)
        })
    }
    
    @inlinable mutating func withUnsafeMutableUInt8Pointer<ResultType>(_ body: (UnsafeMutablePointer<UInt8>?) throws -> ResultType) rethrows -> ResultType {
        return try withUnsafeMutableBytes({ (buffer) -> ResultType in
            let ptr = buffer.bindMemory(to: UInt8.self).baseAddress
            return try body(ptr)
        })
    }
    
}

public extension Optional where Wrapped == Data {
    
    var isNilOrEmpty: Bool {
        switch self {
        case .some(let value):
            return value.isEmpty
        case .none:
            return true
        }
    }
    
}
