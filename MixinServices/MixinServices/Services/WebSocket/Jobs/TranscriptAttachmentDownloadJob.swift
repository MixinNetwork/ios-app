import UIKit

public class TranscriptAttachmentDownloadJob: AttachmentDownloadJob {
    
    let transcriptMessage: MessageItem
    
    override var fileUrl: URL {
        AttachmentContainer.url(conversationId: transcriptMessage.conversationId,
                                transcriptId: transcriptMessage.messageId,
                                filename: fileName)
    }
    
    public init(transcriptMessage: MessageItem, message: Message) {
        self.transcriptMessage = transcriptMessage
        super.init(message: message)
    }
    
    public override class func jobId(messageId: String) -> String {
        "transcript-attachment-\(messageId)"
    }
    
    public override func taskFinished() {
        if message.category == MessageCategory.SIGNAL_VIDEO.rawValue, stream?.streamError == nil {
            let thumbnail = UIImage(withFirstFrameOfVideoAtURL: fileUrl)
            let url = AttachmentContainer.videoThumbnailURL(conversationId: transcriptMessage.conversationId,
                                                            transcriptId: transcriptMessage.messageId,
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
        TranscriptMessageDAO.shared.update(transcriptId: transcriptMessage.messageId,
                                           messageId: message.messageId,
                                           mediaStatus: status,
                                           mediaUrl: fileName)
    }
    
}
