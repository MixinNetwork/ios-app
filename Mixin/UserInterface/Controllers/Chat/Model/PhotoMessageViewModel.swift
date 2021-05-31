import UIKit
import MixinServices

class PhotoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {
    
    var transcriptMessage: MessageItem?
    var isLoading = false
    var progress: Double?
    var downloadIsTriggeredByUser = false
    
    var shouldAutoDownload: Bool {
        switch AppGroupUserDefaults.User.autoDownloadPhotos {
        case .never:
            return false
        case .wifi:
            return ReachabilityManger.shared.isReachableOnEthernetOrWiFi
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
    
    var attachmentURL: URL? {
        if let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty {
            if let transcriptMessage = transcriptMessage {
                return AttachmentContainer.url(transcriptId: transcriptMessage.messageId, filename: mediaUrl)
            } else if !mediaUrl.hasPrefix("http") {
                return AttachmentContainer.url(for: .photos, filename: mediaUrl)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    override init(message: MessageItem) {
        super.init(message: message)
        updateOperationButtonStyle()
        layoutPosition = imageWithRatioMaybeAnArticle(contentRatio) ? .relativeOffset(0) : .center
    }
    
    func beginAttachmentLoading(isTriggeredByUser: Bool) {
        downloadIsTriggeredByUser = isTriggeredByUser
        defer {
            updateOperationButtonStyle()
        }
        guard shouldBeginAttachmentLoading(isTriggeredByUser: isTriggeredByUser) else {
            return
        }
        updateMediaStatus(message: message, status: .PENDING)
        let message = Message.createMessage(message: self.message)
        if shouldUpload {
            if transcriptMessage != nil {
                assertionFailure()
            } else {
                let job = ImageUploadJob(message: message)
                UploaderQueue.shared.addJob(job: job)
            }
        } else {
            let job: BaseJob
            if let transcriptMessage = transcriptMessage {
                job = TranscriptAttachmentDownloadJob(transcriptMessage: transcriptMessage, message: message)
            } else {
                job = AttachmentDownloadJob(messageId: message.messageId)
            }
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        isLoading = true
    }
    
    func cancelAttachmentLoading(isTriggeredByUser: Bool) {
        guard mediaStatus == MediaStatus.PENDING.rawValue else {
            return
        }
        guard isTriggeredByUser || (!downloadIsTriggeredByUser && !shouldUpload) else {
            return
        }
        if shouldUpload {
            if transcriptMessage != nil {
                assertionFailure()
            } else {
                let id = ImageUploadJob.jobId(messageId: message.messageId)
                UploaderQueue.shared.cancelJob(jobId: id)
            }
        } else {
            let id: String
            if transcriptMessage != nil {
                id = TranscriptAttachmentDownloadJob.jobId(messageId: message.messageId)
            } else {
                id = AttachmentDownloadJob.jobId(messageId: message.messageId)
            }
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
        }
        if isTriggeredByUser {
            updateMediaStatus(message: message, status: .CANCELED)
        }
    }
    
}
