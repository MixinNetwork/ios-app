import Foundation

public class FileDownloadJob: AttachmentDownloadJob {
    
    override var fileUrl: URL {
        return AttachmentContainer.url(for: .files, filename: fileName)
    }
    
    override public class func jobId(messageId: String) -> String {
        return "file-download-\(messageId)"
    }
    
    override public func getJobId() -> String {
        return FileDownloadJob.jobId(messageId: messageId)
    }
    
}
