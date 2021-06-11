import UIKit
import MixinServices

class VideoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {

    static let byteCountFormatter = ByteCountFormatter()
    
    private(set) var duration: String?
    private(set) var fileSize: String?
    private(set) var durationLabelOrigin = CGPoint.zero
    
    var transcriptId: String? {
        didSet {
            loadBetterThumbnailIfNeeded()
        }
    }
    var isLoading = false
    var progress: Double?
    var downloadIsTriggeredByUser = false
    
    var shouldAutoDownload: Bool {
        switch AppGroupUserDefaults.User.autoDownloadVideos {
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
    
    private var isBetterThumbnailLoaded = false
    
    override init(message: MessageItem) {
        super.init(message: message)
        update(mediaUrl: message.mediaUrl, mediaSize: message.mediaSize, mediaDuration: message.mediaDuration)
        updateOperationButtonStyle()
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        if style.contains(.received) {
            durationLabelOrigin = CGPoint(x: photoFrame.origin.x + 16,
                                          y: photoFrame.origin.y + 8)
            if quotedMessageViewModel != nil {
                durationLabelOrigin.x -= 9
            }
        } else {
            durationLabelOrigin = CGPoint(x: photoFrame.origin.x + 10,
                                          y: photoFrame.origin.y + 8)
            if quotedMessageViewModel != nil {
                durationLabelOrigin.x -= 2
            }
        }
    }
    
    override func update(mediaUrl: String?, mediaSize: Int64?, mediaDuration: Int64?) {
        super.update(mediaUrl: mediaUrl, mediaSize: mediaSize, mediaDuration: mediaDuration)
        (duration, fileSize) = VideoMessageViewModel.durationAndFileSizeRepresentation(ofMessage: message)
        loadBetterThumbnailIfNeeded()
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
                let job = VideoUploadJob(message: message)
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
                let id = VideoUploadJob.jobId(messageId: message.messageId)
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
    
    private func loadBetterThumbnailIfNeeded() {
        guard !isBetterThumbnailLoaded, let videoFilename = message.mediaUrl else {
            return
        }
        let betterThumbnailURL: URL
        if let transcriptId = transcriptId {
            betterThumbnailURL = AttachmentContainer.videoThumbnailURL(transcriptId: transcriptId, videoFilename: videoFilename)
        } else {
            betterThumbnailURL = AttachmentContainer.videoThumbnailURL(videoFilename: videoFilename)
        }
        if let betterThumbnail = UIImage(contentsOfFile: betterThumbnailURL.path) {
            thumbnail = betterThumbnail
            isBetterThumbnailLoaded = true
        }
    }
    
}
