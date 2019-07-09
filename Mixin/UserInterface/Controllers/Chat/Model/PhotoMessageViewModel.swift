import UIKit

class PhotoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {
    
    var isLoading = false
    var progress: Double?
    
    var automaticallyLoadsAttachment: Bool {
        let shouldAutoDownload: Bool
        switch CommonUserDefault.shared.autoDownloadPhotos {
        case .never:
            shouldAutoDownload = false
        case .wifi:
            shouldAutoDownload = NetworkManager.shared.isReachableOnWiFi
        case .wifiAndCellular:
            shouldAutoDownload = true
        }
        return !shouldUpload && shouldAutoDownload
    }
    
    var automaticallyCancelAttachmentLoading: Bool {
        return true
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
        let job: BaseJob
        if shouldUpload {
            let msg = Message.createMessage(message: message)
            job = ImageUploadJob(message: msg)
        } else {
            job = AttachmentDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType)
        }
        ConcurrentJobQueue.shared.addJob(job: job)
        isLoading = true
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        if shouldUpload {
            let jobId = ImageUploadJob.jobId(messageId: message.messageId)
            ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        } else {
            let jobId = AttachmentDownloadJob.jobId(messageId: message.messageId)
            ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        }
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
}
