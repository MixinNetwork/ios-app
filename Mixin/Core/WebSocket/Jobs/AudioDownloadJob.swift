import Foundation

class AudioDownloadJob: AttachmentDownloadJob {
    
    override lazy var fileName: String = "\(message.messageId).\(FileManager.default.pathExtension(mimeType: message.mediaMimeType ?? ""))"
    override lazy var fileUrl = MixinFile.url(ofChatDirectory: .audios, filename: fileName)
    
    override class func jobId(messageId: String) -> String {
        return "audio-download-\(messageId)"
    }
    
    override func getJobId() -> String {
        return FileDownloadJob.jobId(messageId: messageId)
    }
    
}
