import Foundation
import MixinServices

class VideoUploadJob: AttachmentUploadJob {
    
    override var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl else {
            return nil
        }
        return AttachmentContainer.url(for: .videos, filename: mediaUrl)
    }
    
    override class func jobId(messageId: String) -> String {
        return "video-upload-\(messageId)"
    }
    
    override func execute() -> Bool {
        guard !isCancelled, LoginManager.shared.isLoggedIn else {
            return false
        }
        if message.mediaUrl != nil {
            return super.execute()
        } else {
            return false
        }
    }
    
}
