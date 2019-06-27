import Foundation

class AudioDownloadJob: AttachmentDownloadJob {
    
    override var fileUrl: URL {
        return MixinFile.url(ofChatDirectory: .audios, filename: fileName)
    }
    
    override class func jobId(messageId: String) -> String {
        return "audio-download-\(messageId)"
    }
    
    override func getJobId() -> String {
        return FileDownloadJob.jobId(messageId: messageId)
    }
    
}
