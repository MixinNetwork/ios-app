import UIKit

public extension UIImage {
    
    @discardableResult
    func saveToFile(path: URL, quality: CGFloat = 0.75) -> Bool {
        guard let data = self.jpegData(compressionQuality: quality) else {
            return false
        }
        do {
            try data.write(to: path)
            return true
        } catch {
            return false
        }
    }
    
}
