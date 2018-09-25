import Foundation
import Bugsnag

class FileDownloadJob: AttachmentDownloadJob {

    override var fileName: String {
        return "\(message.messageId).\(FileManager.default.pathExtension(mimeType: message.mediaMimeType ?? ""))"
    }
    
    override var fileUrl: URL {
        return MixinFile.url(ofChatDirectory: .files, filename: fileName)
    }
    
    override class func jobId(messageId: String) -> String {
        return "file-download-\(messageId)"
    }

    override func getJobId() -> String {
        return FileDownloadJob.jobId(messageId: messageId)
    }

}
