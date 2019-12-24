import Foundation

public class VideoDownloadJob: AttachmentDownloadJob {
    
    override var fileUrl: URL {
        return AttachmentContainer.url(for: .videos, filename: fileName)
    }
    
    private lazy var thumbnailUrl = AttachmentContainer.url(for: .videos, filename: messageId + ExtensionName.jpeg.withDot)
    
    override public class func jobId(messageId: String) -> String {
        return "video-download-\(messageId)"
    }
    
    override public func getJobId() -> String {
        return VideoDownloadJob.jobId(messageId: messageId)
    }
    
    override public func taskFinished() {
        super.taskFinished()
        if stream?.streamError == nil {
            let thumbnail = UIImage(withFirstFrameOfVideoAtURL: fileUrl)
            thumbnail?.saveToFile(path: thumbnailUrl)
        }
    }
    
}
