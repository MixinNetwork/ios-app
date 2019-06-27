import Foundation
import Bugsnag

class FileDownloadJob: AttachmentDownloadJob {

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
