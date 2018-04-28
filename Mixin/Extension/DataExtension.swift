import Foundation

extension Data {

    func toHexString() -> String {
        return map { String(format: "%02.2hhx", $0) }.joined()
    }

    var bytes : [UInt8] {
        return [UInt8](self)
    }

    func toString() -> String
    {
        return String(data: self, encoding: .utf8)!
    }
}

