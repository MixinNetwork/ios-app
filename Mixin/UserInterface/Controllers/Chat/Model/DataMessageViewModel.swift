import UIKit

class DataMessageViewModel: CardMessageViewModel, AttachmentLoadingViewModel {

    var isLoading = false
    var progress: Double?
    var showPlayIconAfterFinished: Bool = false
    var operationButtonStyle: NetworkOperationButton.Style = .finished(showPlayIcon: false)
    
    override var size: CGSize {
        return CGSize(width: 280, height: 72)
    }
    
    var automaticallyLoadsAttachment: Bool {
        let shouldAutoDownload: Bool
        switch CommonUserDefault.shared.autoDownloadFiles {
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
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        super.init(message: message, style: style, fits: layoutWidth)
        updateOperationButtonStyle()
    }
    
    func beginAttachmentLoading() {
        defer {
            updateOperationButtonStyle()
        }
        guard message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
        let job: UploadOrDownloadJob
        if shouldUpload {
            job = FileUploadJob(message: Message.createMessage(message: message))
        } else {
            job = FileDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType)
        }
        FileJobQueue.shared.addJob(job: job)
        isLoading = true
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        let jobId: String
        if shouldUpload {
            jobId = FileUploadJob.jobId(messageId: message.messageId)
        } else {
            jobId = FileDownloadJob.jobId(messageId: message.messageId)
        }
        FileJobQueue.shared.cancelJob(jobId: jobId)
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
}
