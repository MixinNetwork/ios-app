import Foundation

extension FileManager {
    
    func fileSize(_ path: String) -> Int64 {
        guard let fileSize = try? attributesOfItem(atPath: path)[FileAttributeKey.size] as? NSNumber else {
            return 0
        }
        return fileSize.int64Value
    }
    
}
