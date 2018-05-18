import Foundation
import Bugsnag

class FileDownloadJob: AttachmentDownloadJob {

    override lazy var fileName: String = "\(message.messageId).\(FileManager.default.pathExtension(mimeType: message.mediaMimeType ?? ""))"
    override lazy var fileUrl = MixinFile.url(ofChatDirectory: .files, filename: fileName)

    override class func jobId(messageId: String) -> String {
        return "file-download-\(messageId)"
    }

    override func getJobId() -> String {
        return FileDownloadJob.jobId(messageId: messageId)
    }

}
