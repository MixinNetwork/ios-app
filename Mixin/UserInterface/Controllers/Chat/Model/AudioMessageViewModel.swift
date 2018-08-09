import UIKit

class AudioMessageViewModel: CardMessageViewModel, AttachmentLoadingViewModel {
    
    let length: String
    let waveform: Waveform
    
    var progress: Double?
    var showPlayIconAfterFinished: Bool = true
    var operationButtonStyle: NetworkOperationButton.Style = .expired
    var operationButtonIsHidden = false
    var playbackStateIsHidden = true
    
    var automaticallyLoadsAttachment: Bool {
        return true
    }
    
    var mediaStatus: String? {
        get {
            return message.mediaStatus
        }
        set {
            message.mediaStatus = newValue
            if newValue != MediaStatus.PENDING.rawValue {
                progress = nil
            }
            updateOperationButtonStyle()
            updateButtonsHidden()
        }
    }
    
    override var size: CGSize {
        return CGSize(width: contentWidth + leftLeadingMargin + leftTrailingMargin + 48 + 10, height: 72)
    }
    
    private let contentWidth: CGFloat

    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        let duration = Int(message.mediaDuration ?? 0)
        let seconds = Int(round(Double(duration) / millisecondsPerSecond))
        length = mediaDurationFormatter.string(from: TimeInterval(seconds)) ?? ""
        contentWidth = WaveformView.estimatedWidth(forDurationInSeconds: seconds)
        self.waveform = Waveform(data: message.mediaWaveform, durationInSeconds: seconds)
        super.init(message: message, style: style, fits: layoutWidth)
        updateOperationButtonStyle()
        updateButtonsHidden()
    }
    
    func beginAttachmentLoading() {
        guard message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
        let job: UploadOrDownloadJob
        if messageIsSentByMe {
            job = AudioUploadJob(message: Message.createMessage(message: message))
        } else {
            job = AudioDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType)
        }
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        let jobId: String
        if messageIsSentByMe {
            jobId = AudioUploadJob.jobId(messageId: message.messageId)
        } else {
            jobId = AudioDownloadJob.jobId(messageId: message.messageId)
        }
        ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
    private func updateButtonsHidden() {
        if case .finished = operationButtonStyle {
            operationButtonIsHidden = true
            playbackStateIsHidden = false
        } else {
            operationButtonIsHidden = false
            playbackStateIsHidden = true
        }
    }

}
