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
        defer {
            updateOperationButtonStyle()
        }
        guard message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
        if shouldUpload {
            UploaderQueue.shared.addJob(job: ImageUploadJob(message: Message.createMessage(message: message)))
        } else {
            ConcurrentJobQueue.shared.addJob(job: AttachmentDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType))
        }

        isLoading = true
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        if shouldUpload {
            UploaderQueue.shared.cancelJob(jobId: ImageUploadJob.jobId(messageId: message.messageId))
        } else {
            ConcurrentJobQueue.shared.cancelJob(jobId: AttachmentDownloadJob.jobId(messageId: message.messageId))
        }
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
}
