import Foundation
import SDWebImage

class LocalImageLoadToken: NSObject {
    
    private(set) var isCancelled = false
    
}

extension LocalImageLoadToken: SDWebImageOperation {
    
    func cancel() {
        isCancelled = true
    }
    
}
