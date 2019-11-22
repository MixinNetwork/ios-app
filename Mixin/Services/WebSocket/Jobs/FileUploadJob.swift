import Foundation

class FileUploadJob: AttachmentUploadJob {

    override var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl else {
            return nil
        }
        return AttachmentContainer.url(for: .files, filename: mediaUrl)
    }
    
    override class func jobId(messageId: String) -> String {
        return "file-upload-\(messageId)"
    }

    override func getJobId() -> String {
        return FileUploadJob.jobId(messageId: messageId)
    }

}
