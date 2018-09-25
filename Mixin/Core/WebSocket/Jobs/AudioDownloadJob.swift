import Foundation

class AudioDownloadJob: AttachmentDownloadJob {
    
    override var fileName: String {
        return "\(message.messageId).\(FileManager.default.pathExtension(mimeType: message.mediaMimeType ?? ""))"
    }
    
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
