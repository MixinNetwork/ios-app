import Foundation

public extension FileManager {
    
    func fileSize(_ path: String) -> Int64 {
        guard let fileSize = try? attributesOfItem(atPath: path)[FileAttributeKey.size] as? NSNumber else {
            return 0
        }
        return fileSize.int64Value
    }
    
    func isAvailable(_ path: String) -> Bool {
        return fileExists(atPath: path) && fileSize(path) > 0
    }
    
    // Returns true if the file is newly created, false if the file already exists
    // Beware this is removing the file with same name if it requires a directory, or vice versa
    @discardableResult
    func createFileIfNotExists(at url: URL, isDirectory shouldBeDirectory: Bool = false) throws -> Bool {
        var isDirectory = ObjCBool(false)
        
        if fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue == shouldBeDirectory {
                return false
            } else {
                try removeItem(at: url)
            }
        }
        
        if shouldBeDirectory {
            try createDirectory(at: url,
                                withIntermediateDirectories: true,
                                attributes: nil)
            return true
        } else {
            let directoryURL = url.deletingLastPathComponent()
            try createFileIfNotExists(at: directoryURL, isDirectory: true)
            try Data().write(to: url)
            return true
        }
    }
    
    @discardableResult @inlinable
    func createDirectoryIfNotExists(at url: URL) throws -> Bool {
        try createFileIfNotExists(at: url, isDirectory: true)
    }
    
}
