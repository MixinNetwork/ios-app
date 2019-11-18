import UIKit

class PhotoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {
    
    var isLoading = false
    var progress: Double?
    var downloadIsTriggeredByUser = false
    
    var shouldAutoDownload: Bool {
        switch AppGroupUserDefaults.User.autoDownloadPhotos {
        case .never:
            return false
        case .wifi:
            return NetworkManager.shared.isReachableOnWiFi
        case .wifiAndCellular:
            return true
        }
    }
    
    var automaticallyLoadsAttachment: Bool {
        return !shouldUpload && shouldAutoDownload
    }
    
    var showPlayIconOnMediaStatusDone: Bool {
        return false
    }
    
    override init(message: MessageItem) {
        super.init(message: message)
        updateOperationButtonStyle()
        layoutPosition = GalleryItem.shouldLayoutImageOfRatioAsAriticle(contentRatio) ? .relativeOffset(0) : .center
    }
    
    func beginAttachmentLoading(isTriggeredByUser: Bool) {
        downloadIsTriggeredByUser = isTriggeredByUser
        defer {
            updateOperationButtonStyle()
        }
        guard shouldBeginAttachmentLoading(isTriggeredByUser: isTriggeredByUser) else {
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
    
    func cancelAttachmentLoading(isTriggeredByUser: Bool) {
        guard mediaStatus == MediaStatus.PENDING.rawValue else {
            return
        }
        guard isTriggeredByUser || !downloadIsTriggeredByUser else {
            return
        }
        if shouldUpload {
            UploaderQueue.shared.cancelJob(jobId: ImageUploadJob.jobId(messageId: message.messageId))
        } else {
            ConcurrentJobQueue.shared.cancelJob(jobId: AttachmentDownloadJob.jobId(messageId: message.messageId))
        }
        if isTriggeredByUser {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
}
