import Foundation

class FileDownloadJob: AttachmentDownloadJob {

    override var fileUrl: URL {
        return AttachmentContainer.url(for: .files, filename: fileName)
    }
    
    override class func jobId(messageId: String) -> String {
        return "file-download-\(messageId)"
    }

    override func getJobId() -> String {
        return FileDownloadJob.jobId(messageId: messageId)
    }

}
