import UIKit

public class TranscriptAttachmentDownloadJob: AttachmentDownloadJob {
    
    let transcriptId: String
    
    override var fileUrl: URL {
        AttachmentContainer.url(transcriptId: transcriptId,
                                filename: fileName)
    }
    
    public init(transcriptId: String, message: Message) {
        self.transcriptId = transcriptId
        super.init(message: message)
    }
    
    public override class func jobId(messageId: String) -> String {
        "transcript-attachment-\(messageId)"
    }
    
    public override func taskFinished() {
        if message.category == MessageCategory.SIGNAL_VIDEO.rawValue, stream?.streamError == nil {
            let thumbnail = UIImage(withFirstFrameOfVideoAtURL: fileUrl)
            let url = AttachmentContainer.videoThumbnailURL(transcriptId: transcriptId,
                                                            videoFilename: fileName)
            thumbnail?.saveToFile(path: url)
        }
        super.taskFinished()
    }
    
    public override func updateMediaMessage(
        messageId: String,
        mediaUrl: String,
        status: MediaStatus,
        conversationId: String,
        content: String? = nil
    ) {
        TranscriptMessageDAO.shared.update(transcriptId: transcriptId,
                                           messageId: message.messageId,
                                           mediaStatus: status,
                                           mediaUrl: fileName)
    }
    
}
