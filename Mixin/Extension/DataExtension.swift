import Foundation

extension Data {
    
    var bytes : [UInt8] {
        return [UInt8](self)
    }
    
    init?(withSecuredRandomBytesOfCount count: Int) {
        guard let bytes = malloc(count) else {
            return nil
        }
        let status = SecRandomCopyBytes(kSecRandomDefault, count, bytes)
        guard status == errSecSuccess else {
            return nil
        }
        self.init(bytesNoCopy: bytes, count: count, deallocator: .free)
    }
    
    func toHexString() -> String {
        return map { String(format: "%02.2hhx", $0) }.joined()
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
    
}

