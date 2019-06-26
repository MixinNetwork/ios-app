import Foundation

class AudioJobQueue: JobQueue {
    
    static let shared = FileJobQueue()
    
    init() {
        super.init(maxConcurrentOperationCount: 2)
    }
    
}
