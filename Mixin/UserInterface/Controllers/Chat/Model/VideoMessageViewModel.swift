import UIKit

class VideoMessageViewModel: PhotoRepresentableMessageViewModel, AttachmentLoadingViewModel {

    let betterThumbnail: UIImage?
    
    var progress: Double?
    
    var automaticallyLoadsAttachment: Bool {
        return false
    }
    
    var showPlayIconAfterFinished: Bool {
        return true
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        if let mediaUrl = message.mediaUrl, let filename = mediaUrl.components(separatedBy: ".").first {
            let betterThumbnailFilename = filename + jpegExtensionName
            let betterThumbnailURL = MixinFile.url(ofChatDirectory: .videos,
                                                   filename: betterThumbnailFilename)
            betterThumbnail = UIImage(contentsOfFile: betterThumbnailURL.path)
        } else {
            betterThumbnail = nil
        }
        super.init(message: message, style: style, fits: layoutWidth)
        updateOperationButtonStyle()
    }
    
    func beginAttachmentLoading() {
        guard message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
        let job: UploadOrDownloadJob
        if messageIsSentByMe {
            job = VideoUploadJob(message: Message.createMessage(message: message))
        } else {
            job = VideoDownloadJob(messageId: message.messageId)
        }
        FileJobQueue.shared.addJob(job: job)
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        let jobId: String
        if messageIsSentByMe {
            jobId = VideoUploadJob.jobId(messageId: message.messageId)
        } else {
            jobId = VideoDownloadJob.jobId(messageId: message.messageId)
        }
        FileJobQueue.shared.cancelJob(jobId: jobId)
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
}
