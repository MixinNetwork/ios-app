import UIKit

class PhotoMessageViewModel: DetailInfoMessageViewModel, AttachmentLoadingViewModel {
    
    static let contentWidth: CGFloat = 220
    static let maxHeight: CGFloat = UIScreen.main.bounds.height / 2
    static let leftShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_left")
    static let rightShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_right")
    static let rightWithTailShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_right_tail")
    
    internal(set) var contentFrame = CGRect.zero
    internal(set) var shadowImage: UIImage?
    internal(set) var shadowImageOrigin = CGPoint.zero
    internal(set) var operationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)

    override lazy var contentMargin: Margin = {
        Margin(leading: 9, trailing: 5, top: 4, bottom: 6)
    }()
    
    private let contentSize: CGSize
    
    var progress: Double?

    var automaticallyLoadsAttachment: Bool {
        return mediaStatus == MediaStatus.PENDING.rawValue && !messageIsSentByMe
    }
    
    var showPlayIconAfterFinished: Bool {
        return false
    }
    
    override var statusNormalTintColor: UIColor {
        return .white
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        let contentWidth = PhotoMessageViewModel.contentWidth
        let mediaWidth = CGFloat(message.mediaWidth ?? 1)
        var mediaHeight = CGFloat(message.mediaHeight ?? 1)
        if mediaHeight == 0 {
            mediaHeight = 1
        }
        let ratio = mediaWidth / mediaHeight
        contentSize = CGSize(width: contentWidth,
                             height: min(PhotoMessageViewModel.maxHeight, contentWidth / ratio))
        super.init(message: message, style: style, fits: layoutWidth)
        updateOperationButtonStyle()
    }
    
    override func didSetStyle() {
        let backgroundImageMargin = MessageViewModel.backgroundImageMargin
        let bottomSeparatorHeight = style.contains(.hasBottomSeparator) ? MessageViewModel.bottomSeparatorHeight : 0
        let fullnameHeight = style.contains(.showFullname) ? fullnameFrame.height : 0
        if style.contains(.sent) {
            if style.contains(.hasTail) {
                shadowImage = PhotoMessageViewModel.rightWithTailShadowImage
            } else {
                shadowImage = PhotoMessageViewModel.rightShadowImage
            }
        } else {
            shadowImage = PhotoMessageViewModel.leftShadowImage
        }
        let shadowImageSize = shadowImage?.size ?? .zero
        if style.contains(.received) {
            contentFrame = CGRect(x: backgroundImageMargin.leading,
                                  y: backgroundImageMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            shadowImageOrigin = CGPoint(x: contentFrame.maxX - shadowImageSize.width,
                                        y: contentFrame.maxY - shadowImageSize.height)
            if style.contains(.showFullname) {
                contentFrame.origin.y += fullnameHeight
                shadowImageOrigin.y += fullnameHeight
            }
        } else if style.contains(.sent) {
            contentFrame = CGRect(x: layoutWidth - backgroundImageMargin.leading - contentSize.width,
                                  y: backgroundImageMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            shadowImageOrigin = CGPoint(x: contentFrame.maxX - shadowImageSize.width,
                                        y: contentFrame.maxY - shadowImageSize.height)
        }
        backgroundImageFrame = CGRect(origin: .zero, size: contentFrame.size)
        cellHeight = fullnameHeight + backgroundImageFrame.size.height + bottomSeparatorHeight
        super.didSetStyle()
        timeFrame.origin.x += contentFrame.origin.x
        timeFrame.origin.y += fullnameHeight
        if style.contains(.sent) {
            statusFrame.origin.x = timeFrame.maxX + DetailInfoMessageViewModel.statusLeftMargin
        }
        statusFrame.origin.y += fullnameHeight
    }
    
    func beginAttachmentLoading() {
        guard message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
        let job: UploadOrDownloadJob
        if messageIsSentByMe {
            job = AttachmentUploadJob(message: Message.createMessage(message: message))
        } else {
            job = AttachmentDownloadJob(messageId: message.messageId)
        }
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool) {
        let jobId: String
        if messageIsSentByMe {
            jobId = AttachmentUploadJob.jobId(messageId: message.messageId)
        } else {
            jobId = AttachmentDownloadJob.jobId(messageId: message.messageId)
        }
        ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        if markMediaStatusCancelled {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
        }
    }
    
}
