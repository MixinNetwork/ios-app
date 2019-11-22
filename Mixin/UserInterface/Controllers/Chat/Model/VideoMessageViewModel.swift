import UIKit

class VideoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {

    static let byteCountFormatter = ByteCountFormatter()
    
    private(set) var duration: String?
    private(set) var fileSize: String?
    private(set) var durationLabelOrigin = CGPoint.zero
    
    var isLoading = false
    var progress: Double?
    var downloadIsTriggeredByUser = false
    
    var shouldAutoDownload: Bool {
        switch AppGroupUserDefaults.User.autoDownloadVideos {
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
            (duration, fileSize) = VideoMessageViewModel.durationAndFileSizeRepresentation(ofMessage: message)
        }
    }
    
    override init(message: MessageItem) {
        super.init(message: message)
        update(mediaUrl: message.mediaUrl, mediaSize: message.mediaSize, mediaDuration: message.mediaDuration)
        updateOperationButtonStyle()
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        if style.contains(.received) {
            durationLabelOrigin = CGPoint(x: contentFrame.origin.x + 16,
                                          y: contentFrame.origin.y + 8)
        } else {
            durationLabelOrigin = CGPoint(x: contentFrame.origin.x + 10,
                                          y: contentFrame.origin.y + 8)
        }
    }
    
    override func update(mediaUrl: String?, mediaSize: Int64?, mediaDuration: Int64?) {
        super.update(mediaUrl: mediaUrl, mediaSize: mediaSize, mediaDuration: mediaDuration)
        (duration, fileSize) = VideoMessageViewModel.durationAndFileSizeRepresentation(ofMessage: message)
        if let mediaUrl = mediaUrl, let filename = mediaUrl.components(separatedBy: ".").first {
            let betterThumbnailFilename = filename + ExtensionName.jpeg.withDot
            let betterThumbnailURL = AttachmentContainer.url(for: .videos, filename: betterThumbnailFilename)
            if let betterThumbnail = UIImage(contentsOfFile: betterThumbnailURL.path) {
                thumbnail = betterThumbnail
            }
        }
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
            UploaderQueue.shared.addJob(job: VideoUploadJob(message: Message.createMessage(message: message)))
        } else {
            ConcurrentJobQueue.shared.addJob(job: VideoDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType))
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
            UploaderQueue.shared.cancelJob(jobId: VideoUploadJob.jobId(messageId: message.messageId))
        } else {
            ConcurrentJobQueue.shared.cancelJob(jobId: VideoDownloadJob.jobId(messageId: message.messageId))
        }
        if isTriggeredByUser {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
    private static func durationAndFileSizeRepresentation(ofMessage message: MessageItem) -> (String?, String?) {
        var duration: String?
        if let mediaDuration = message.mediaDuration {
            duration = mediaDurationFormatter.string(from: TimeInterval(Double(mediaDuration) / millisecondsPerSecond))
        }
        
        var fileSize: String?
        if let mediaSize = message.mediaSize {
            fileSize = VideoMessageViewModel.byteCountFormatter.string(fromByteCount: mediaSize)
        }
        
        return (duration, fileSize)
    }
    
}
