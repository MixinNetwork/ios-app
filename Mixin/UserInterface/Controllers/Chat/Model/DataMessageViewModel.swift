import UIKit
import MixinServices

class DataMessageViewModel: CardMessageViewModel, AttachmentLoadingViewModel {
    
    override class var supportsQuoting: Bool {
        true
    }
    
    override class var isContentWidthLimited: Bool {
        false
    }
    
    let isListPlayable: Bool
    
    var transcriptId: String? {
        didSet {
            updateOperationButtonStyle()
        }
    }
    var isLoading = false
    var progress: Double?
    var operationButtonStyle: NetworkOperationButton.Style = .finished(showPlayIcon: false)
    var downloadIsTriggeredByUser = false
    
    var showPlayIconOnMediaStatusDone: Bool {
        isListPlayable && transcriptId == nil
    }
    
    var shouldAutoDownload: Bool {
        switch AppGroupUserDefaults.User.autoDownloadFiles {
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
    
    override init(message: MessageItem) {
        isListPlayable = message.isListPlayable
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
        updateMediaStatus(message: message, status: .PENDING)
        let message = Message.createMessage(message: self.message)
        if shouldUpload {
            if transcriptId != nil {
                assertionFailure()
            } else {
                let job = FileUploadJob(message: message)
                UploaderQueue.shared.addJob(job: job)
            }
        } else {
            let job = AttachmentDownloadJob(transcriptId: transcriptId, messageId: message.messageId)
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
            if transcriptId != nil {
                assertionFailure()
            } else {
                let id = FileUploadJob.jobId(messageId: message.messageId)
                UploaderQueue.shared.cancelJob(jobId: id)
            }
        } else {
            let id = AttachmentDownloadJob.jobId(transcriptId: transcriptId, messageId: message.messageId)
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
        }
        if isTriggeredByUser {
            updateMediaStatus(message: message, status: .CANCELED)
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
