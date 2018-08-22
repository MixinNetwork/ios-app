import UIKit

class PhotoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {
    
    var progress: Double?

    var automaticallyLoadsAttachment: Bool {
        return mediaStatus == MediaStatus.PENDING.rawValue && !messageIsSentByMe
    }
    
    var showPlayIconAfterFinished: Bool {
        return false
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        super.init(message: message, style: style, fits: layoutWidth)
        updateOperationButtonStyle()
        layoutPosition = GalleryItem.shouldLayoutImageOfRatioAsAriticle(aspectRatio) ? .top : .center
    }
    
    func beginAttachmentLoading() {
        guard message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
        let job: UploadOrDownloadJob
        if messageIsSentByMe {
            job = AttachmentUploadJob(message: Message.createMessage(message: message))
        } else {
            job = AttachmentDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType)
        }
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        let jobId: String
        if messageIsSentByMe {
            jobId = AttachmentUploadJob.jobId(messageId: message.messageId)
        } else {
            jobId = AttachmentDownloadJob.jobId(messageId: message.messageId)
        }
        ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
}
