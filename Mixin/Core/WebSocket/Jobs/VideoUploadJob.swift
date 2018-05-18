import Foundation

class VideoUploadJob: AttachmentUploadJob {
    
    override var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl else {
            return nil
        }
        return MixinFile.url(ofChatDirectory: .videos, filename: mediaUrl)
    }
    
    override class func jobId(messageId: String) -> String {
        return "video-upload-\(messageId)"
    }
    
    override func getJobId() -> String {
        return VideoUploadJob.jobId(messageId: messageId)
    }
    
}
