import Foundation

class AudioJobQueue: JobQueue {
    
    static let shared = AudioJobQueue()
    
    init() {
        super.init(maxConcurrentOperationCount: 2)
    }
    
}
