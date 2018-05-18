import Foundation
import Bugsnag

class VideoDownloadJob: AttachmentDownloadJob {
    
    override lazy var fileName: String = "\(message.messageId).\(FileManager.default.pathExtension(mimeType: message.mediaMineType ?? ""))"
    override lazy var fileUrl = MixinFile.url(ofChatDirectory: .videos, filename: fileName)

    override class func jobId(messageId: String) -> String {
        return "video-download-\(messageId)"
    }
    
    override func getJobId() -> String {
        return VideoDownloadJob.jobId(messageId: messageId)
    }
    
}
