import Foundation

class AudioUploadJob: AttachmentUploadJob {
    
    override var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl else {
            return nil
        }
        return MixinFile.url(ofChatDirectory: .audios, filename: mediaUrl)
    }
    
    override class func jobId(messageId: String) -> String {
        return "audio-upload-\(messageId)"
    }
    
    override func getJobId() -> String {
        return AudioUploadJob.jobId(messageId: messageId)
    }
    
}
