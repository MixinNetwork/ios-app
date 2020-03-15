import Foundation

public extension FileManager {
    
    func fileSize(_ path: String) -> Int64 {
        guard let fileSize = try? attributesOfItem(atPath: path)[FileAttributeKey.size] as? NSNumber else {
            return 0
        }
        return fileSize.int64Value
    }
    
    func createDirectoryIfNotExists(atPath path: String) throws {
        guard !FileManager.default.fileExists(atPath: path) else {
            return
        }
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }

    func isAvailable(_ path: String) -> Bool {
        return fileExists(atPath: path) && fileSize(path) > 0
    }
    
}
