import UIKit

public class TranscriptAttachmentDownloadJob: AttachmentDownloadJob {
    
    public static let fileExpiredNotification = Notification.Name("one.mixin.services.TranscriptAttachmentDownloadJob.FileExpired")
    public static let didCancelNotification = Notification.Name("one.mixin.services.TranscriptAttachmentDownloadJob.DidCancel")
    
    let transcriptMessageId: String
    
    override var fileUrl: URL {
        AttachmentContainer.url(forTranscriptMessageWith: transcriptMessageId,
                                filename: fileName)
    }
    
    public init(transcriptMessageId: String, message: Message) {
        self.transcriptMessageId = transcriptMessageId
        super.init(message: message)
    }
    
    public override class func jobId(messageId: String) -> String {
        "transcript-attachment-\(messageId)"
    }
    
    public override func taskFinished() {
        if message.category == MessageCategory.SIGNAL_VIDEO.rawValue, stream?.streamError == nil {
            let thumbnail = UIImage(withFirstFrameOfVideoAtURL: fileUrl)
            let url = AttachmentContainer.videoThumbnailURL(forTranscriptMessageWith: transcriptMessageId,
                                                            videoFilename: fileName)
            thumbnail?.saveToFile(path: url)
        }
        super.taskFinished()
    }
    
    public override func downloadExpired() {
        NotificationCenter.default.post(onMainThread: Self.fileExpiredNotification,
                                        object: self,
                                        userInfo: [Self.UserInfoKey.messageId: message.messageId])
    }
    
    public override func updateMediaMessage(
        messageId: String,
        mediaUrl: String,
        status: MediaStatus,
        conversationId: String,
        content: String? = nil
    ) {
        if status == .CANCELED {
            NotificationCenter.default.post(onMainThread: Self.didCancelNotification,
                                            object: self,
                                            userInfo: [Self.UserInfoKey.messageId: message.messageId])
        }
    }
    
}
