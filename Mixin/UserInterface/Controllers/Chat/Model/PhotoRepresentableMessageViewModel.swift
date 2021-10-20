import UIKit
import MixinServices

class PhotoRepresentableMessageViewModel: ImageMessageViewModel {
    
    let contentSize: CGSize
    
    var operationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)
    var layoutPosition = VerticalPositioningImageView.Position.center
    var expandIconOrigin: CGPoint?
    
    private struct PresentationSize {
        static let maxHeight: CGFloat = 280
        static let maxWidth: CGFloat = 210
        static let minHeight: CGFloat = 120
        static let minWidth: CGFloat = 120
        static let maxRatio: CGFloat = maxHeight / maxWidth
    }
    
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
        let ratio = contentSize.height / contentSize.width
        let scaledHeight: CGFloat
        let scaledWidth: CGFloat
        if contentSize.width > PresentationSize.maxWidth && contentSize.height > PresentationSize.maxHeight {
            if ratio > 1 {
                if ratio > PresentationSize.maxRatio {
                    scaledHeight = PresentationSize.maxHeight
                    scaledWidth = round(scaledHeight / ratio)
                } else {
                    scaledWidth = PresentationSize.maxWidth
                    scaledHeight = round(scaledWidth * ratio)
                }
            } else {
                scaledWidth = PresentationSize.maxWidth
                scaledHeight = max(PresentationSize.minHeight, round(scaledWidth * ratio))
            }
        } else if contentSize.height > PresentationSize.maxHeight && contentSize.width < PresentationSize.maxWidth {
            scaledHeight = PresentationSize.maxHeight
            scaledWidth = max(PresentationSize.minWidth, round(scaledHeight / ratio))
        } else if contentSize.width > PresentationSize.maxWidth && contentSize.height < PresentationSize.maxHeight {
            scaledWidth = PresentationSize.maxWidth
            scaledHeight = max(PresentationSize.minHeight, round(scaledWidth * ratio))
        } else if contentSize.width > PresentationSize.minWidth && contentSize.height < PresentationSize.minHeight {
            scaledHeight = PresentationSize.minHeight
            scaledWidth = min(PresentationSize.maxWidth, round(scaledHeight / ratio))
        } else if contentSize.height > PresentationSize.minHeight && contentSize.width < PresentationSize.minWidth {
            scaledWidth = PresentationSize.minWidth
            scaledHeight = min(PresentationSize.maxHeight, round(scaledWidth * ratio))
        } else if contentSize.height < PresentationSize.minHeight && contentSize.width < PresentationSize.minWidth {
            if ratio > 1 {
                scaledWidth = PresentationSize.minWidth
                scaledHeight = min(PresentationSize.maxHeight, round(scaledWidth * ratio))
            } else {
                scaledHeight = PresentationSize.minHeight
                scaledWidth = min(PresentationSize.maxWidth, round(scaledHeight / ratio))
            }
        } else {
            scaledWidth = contentSize.width
            scaledHeight = contentSize.height
        }
        photoFrame.size = CGSize(width: scaledWidth, height: scaledHeight)
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
