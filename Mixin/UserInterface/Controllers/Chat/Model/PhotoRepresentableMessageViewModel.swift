import UIKit
import MixinServices

class PhotoRepresentableMessageViewModel: ImageMessageViewModel {
    
    let contentSize: CGSize
    
    var operationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)
    var layoutPosition = VerticalPositioningImageView.Position.center
    var expandIconOrigin: CGPoint?
    
    override init(message: MessageItem) {
        let mediaWidth = abs(CGFloat(message.mediaWidth ?? 0))
        let mediaHeight = abs(CGFloat(message.mediaHeight ?? 0))
        if mediaWidth < 1 || mediaHeight < 1 {
            contentSize = CGSize(width: 1, height: 1)
        } else {
            contentSize = CGSize(width: mediaWidth, height: mediaHeight)
        }
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        photoFrame.size = PhotoSizeCalculator.displaySize(for: contentSize)
        super.layout(width: width, style: style)
        layoutTrailingInfoBackgroundFrame()
        if imageWithRatioMaybeAnArticle(contentSize) {
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
