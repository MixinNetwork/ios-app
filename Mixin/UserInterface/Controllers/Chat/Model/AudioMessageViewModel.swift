import UIKit
import MixinServices

class AudioMessageViewModel: CardMessageViewModel, AttachmentLoadingViewModel {
    
    override class var supportsQuoting: Bool {
        true
    }
    
    let length: String
    let waveform: Waveform
    
    var isLoading = false
    var progress: Double?
    var showPlayIconOnMediaStatusDone: Bool = true
    var operationButtonStyle: NetworkOperationButton.Style = .expired
    var operationButtonIsHidden = false
    var playbackStateIsHidden = true
    var downloadIsTriggeredByUser = false
    
    var isUnread: Bool {
        return message.userId != myUserId
            && mediaStatus != MediaStatus.READ.rawValue
    }
    
    var shouldAutoDownload: Bool {
        return true
    }
    
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
                isLoading = false
            }
            updateOperationButtonStyle()
            updateButtonsHidden()
        }
    }
    
    override var contentWidth: CGFloat {
        waveformWidth + leftLeadingMargin + leftTrailingMargin + 40 + 10
    }
    
    private let waveformWidth: CGFloat

    override init(message: MessageItem) {
        let duration = Int(message.mediaDuration ?? 0)
        let seconds = Int(round(Double(duration) / millisecondsPerSecond))
        length = mediaDurationFormatter.string(from: TimeInterval(seconds)) ?? ""
        waveformWidth = WaveformView.estimatedWidth(forDurationInSeconds: seconds)
        self.waveform = Waveform(data: message.mediaWaveform, durationInSeconds: seconds)
        super.init(message: message)
        updateOperationButtonStyle()
        updateButtonsHidden()
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
            UploaderQueue.shared.addJob(job: AudioUploadJob(message: Message.createMessage(message: message)))
        } else {
            ConcurrentJobQueue.shared.addJob(job: AudioDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType))
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
            UploaderQueue.shared.cancelJob(jobId: AudioUploadJob.jobId(messageId: message.messageId))
        } else {
            ConcurrentJobQueue.shared.cancelJob(jobId: AudioDownloadJob.jobId(messageId: message.messageId))
        }
        if isTriggeredByUser {
            updateMediaStatus(messageId: message.messageId, conversationId: message.conversationId, status: .CANCELED)
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
