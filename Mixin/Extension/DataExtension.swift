import Foundation

extension Data {

    func toHexString() -> String {
        return map { String(format: "%02.2hhx", $0) }.joined()
    }

    var bytes : [UInt8] {
        return [UInt8](self)
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

