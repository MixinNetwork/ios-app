import Foundation

public final class TranscriptAttachmentLoadingQueue: JobQueue {
    
    public static let shared = TranscriptAttachmentLoadingQueue()
    
    internal init() {
        super.init(maxConcurrentOperationCount: 1)
    }
    
}
