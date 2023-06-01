import Foundation
import MixinServices

enum DeviceTransferData: String {
    
    case record
    case file
    
    static let payloadLength: UInt64 = 4
    static let maxSizePerFile = 10 * Int(bytesPerMegaByte)

    static func url() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DeviceTransfer", isDirectory: true)
        _ = try? FileManager.default.createDirectoryIfNotExists(at: url)
        return url
    }
    
    func url(index: Int?) -> URL {
        if let index {
            return url(name: "\(index)")
        } else {
            return url(name: nil)
        }
    }
    
    func url(name: String?) -> URL {
        let url = Self.url().appendingPathComponent(self.rawValue, isDirectory: true)
        _ = try? FileManager.default.createDirectoryIfNotExists(at: url)
        if let name {
            return url.appendingPathComponent("\(name).bin")
        } else {
            return url
        }
    }
    
}
