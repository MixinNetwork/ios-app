import UIKit

class VideoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {

    static let byteCountFormatter = ByteCountFormatter()
    
    private(set) var duration: String?
    private(set) var fileSize: String?
    private(set) var durationLabelOrigin = CGPoint.zero
    
    var progress: Double?
    
    var automaticallyLoadsAttachment: Bool {
        return false
    }
    
    var showPlayIconAfterFinished: Bool {
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
            (duration, fileSize) = VideoMessageViewModel.durationAndFileSizeRepresentation(ofMessage: message)
        }
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        (duration, fileSize) = VideoMessageViewModel.durationAndFileSizeRepresentation(ofMessage: message)
        super.init(message: message, style: style, fits: layoutWidth)
        upgradeThumbnailIfNeeded(mediaUrl: message.mediaUrl)
        updateOperationButtonStyle()
        if style.contains(.received) {
            durationLabelOrigin = CGPoint(x: contentFrame.origin.x + 16,
                                          y: contentFrame.origin.y + 8)
        } else {
            durationLabelOrigin = CGPoint(x: contentFrame.origin.x + 10,
                                          y: contentFrame.origin.y + 8)
        }
    }
    
    override func upgradeThumbnailIfNeeded(mediaUrl: String?) {
        guard let mediaUrl = mediaUrl, let filename = mediaUrl.components(separatedBy: ".").first else {
            return
        }
        let betterThumbnailFilename = filename + ExtensionName.jpeg.withDot
        let betterThumbnailURL = MixinFile.url(ofChatDirectory: .videos, filename: betterThumbnailFilename)
        if let betterThumbnail = UIImage(contentsOfFile: betterThumbnailURL.path) {
            thumbnail = betterThumbnail
        }
    }
    
    func beginAttachmentLoading() {
        guard message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
        if shouldUpload {
            let msg = Message.createMessage(message: message)
            let job = VideoUploadJob(message: msg)
            ConcurrentJobQueue.shared.addJob(job: job)
        } else {
            let job = VideoDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType)
            FileJobQueue.shared.addJob(job: job)
        }
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        if shouldUpload {
            let id = VideoUploadJob.jobId(messageId: message.messageId)
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
        } else {
            let jobId = VideoDownloadJob.jobId(messageId: message.messageId)
            FileJobQueue.shared.cancelJob(jobId: jobId)
        }
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
    private static func durationAndFileSizeRepresentation(ofMessage message: MessageItem) -> (String?, String?) {
        if message.mediaStatus == MediaStatus.DONE.rawValue {
            var duration: String?
            if let mediaDuration = message.mediaDuration {
                duration = mediaDurationFormatter.string(from: TimeInterval(Double(mediaDuration) / millisecondsPerSecond))
            }
            return (duration, nil)
        } else {
            var fileSize: String?
            if let mediaSize = message.mediaSize {
                fileSize = VideoMessageViewModel.byteCountFormatter.string(fromByteCount: mediaSize)
            }
            return (nil, fileSize)
        }
    }
    
}
