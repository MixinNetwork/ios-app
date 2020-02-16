import UIKit
import MixinServices

class DataMessageViewModel: CardMessageViewModel, AttachmentLoadingViewModel {
    
    override class var supportsQuoting: Bool {
        true
    }
    
    override class var isContentWidthLimited: Bool {
        false
    }
    
    var isLoading = false
    var progress: Double?
    var showPlayIconOnMediaStatusDone: Bool = false
    var operationButtonStyle: NetworkOperationButton.Style = .finished(showPlayIcon: false)
    var downloadIsTriggeredByUser = false
    
    var shouldAutoDownload: Bool {
        switch AppGroupUserDefaults.User.autoDownloadFiles {
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
    
    override init(message: MessageItem) {
        super.init(message: message)
        updateOperationButtonStyle()
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        contentWidth = 240
        super.layout(width: width, style: style)
        layoutQuotedMessageIfPresent()
    }
    
    func beginAttachmentLoading(isTriggeredByUser: Bool) {
        downloadIsTriggeredByUser = isTriggeredByUser
        defer {
            updateOperationButtonStyle()
        }
        guard shouldBeginAttachmentLoading(isTriggeredByUser: isTriggeredByUser) else {
            return
        }
        updateMediaStatus(messageId: message.messageId, conversationId: message.conversationId, status: .PENDING)
        if shouldUpload {
            UploaderQueue.shared.addJob(job: FileUploadJob(message: Message.createMessage(message: message)))
        } else {
            ConcurrentJobQueue.shared.addJob(job: FileDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType))
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
            UploaderQueue.shared.cancelJob(jobId: FileUploadJob.jobId(messageId: message.messageId))
        } else {
            ConcurrentJobQueue.shared.cancelJob(jobId: FileDownloadJob.jobId(messageId: message.messageId))
        }
        if isTriggeredByUser {
            updateMediaStatus(messageId: message.messageId, conversationId: message.conversationId, status: .CANCELED)
        }
    }
    
}

extension DataMessageViewModel: SharedMediaItem {
    
    var messageId: String {
        return message.messageId
    }
    
    var createdAt: String {
        return message.createdAt
    }
    
}
