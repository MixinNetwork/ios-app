import UIKit
import MixinServices

class PhotoRepresentableMessageViewModel: ImageMessageViewModel {
    
    let contentRatio: CGSize
    
    var operationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)
    var layoutPosition = VerticalPositioningImageView.Position.center
    var expandIconOrigin: CGPoint?
    
    private var maxPresentationHeight: CGFloat {
        return Queue.main.autoSync {
            AppDelegate.current.mainWindow.bounds.height / 2
        }
    }
    
    override init(message: MessageItem) {
        let mediaWidth = abs(CGFloat(message.mediaWidth ?? 0))
        let mediaHeight = abs(CGFloat(message.mediaHeight ?? 0))
        if mediaWidth < 1 || mediaHeight < 1 {
            contentRatio = CGSize(width: 1, height: 1)
        } else {
            contentRatio = CGSize(width: mediaWidth, height: mediaHeight)
        }
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        let ratio = contentRatio.width / contentRatio.height
        if quotedMessageViewModel == nil {
            let photoHeight = min(maxPresentationHeight, round(Self.bubbleWidth / ratio))
            photoFrame.size = CGSize(width: Self.bubbleWidth, height: photoHeight)
        } else {
            let photoWidth = Self.bubbleWidth - Self.quotingMessageMargin.horizontal
            let photoHeight = min(maxPresentationHeight, round(photoWidth / ratio))
            photoFrame.size = CGSize(width: photoWidth, height: photoHeight)
        }
        super.layout(width: width, style: style)
        layoutTrailingInfoBackgroundFrame()
        if imageWithRatioMaybeAnArticle(contentRatio) {
            let margin: CGFloat
            if style.contains(.received) {
                margin = 9
            } else {
                margin = 16
            }
            let iconWidth = R.image.conversation.ic_message_expand()!.size.width
            expandIconOrigin = CGPoint(x: backgroundImageFrame.maxX - iconWidth - margin,
                                       y: photoFrame.origin.y + 8)
        } else {
            expandIconOrigin = nil
        }
    }
    
    func update(mediaUrl: String?, mediaSize: Int64?, mediaDuration: Int64?) {
        message.mediaUrl = mediaUrl
        message.mediaSize = mediaSize
        message.mediaDuration = mediaDuration
    }
    
}
