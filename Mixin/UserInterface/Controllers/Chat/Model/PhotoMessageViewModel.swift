import UIKit

class PhotoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {
    
    var progress: Double?

    var automaticallyLoadsAttachment: Bool {
        return mediaStatus == MediaStatus.PENDING.rawValue && !shouldUpload
    }
    
    var showPlayIconAfterFinished: Bool {
        return false
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        super.init(message: message, style: style, fits: layoutWidth)
        updateOperationButtonStyle()
        layoutPosition = GalleryItem.shouldLayoutImageOfRatioAsAriticle(aspectRatio) ? .relativeOffset(0) : .center
    }
    
    func beginAttachmentLoading() {
        guard message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
        if shouldUpload {
            let msg = Message.createMessage(message: message)
            AssetUploadJobGroup.jobs(message: msg)?.forEach({ (job) in
                ConcurrentJobQueue.shared.addJob(job: job)
            })
        } else {
            let job = AttachmentDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType)
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        if shouldUpload {
            AssetUploadJobGroup.cancelJobs(on: ConcurrentJobQueue.shared, for: message)
        } else {
            let jobId = AttachmentDownloadJob.jobId(messageId: message.messageId)
            ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        }
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
}
