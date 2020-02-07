import UIKit
import MixinServices

class PhotoRepresentableMessageViewModel: DetailInfoMessageViewModel, BackgroundedTrailingInfoViewModel {
    
    static let quotingMessageMargin = Margin(leading: 4, trailing: 11, top: 2, bottom: 5)
    
    // This is the fixed width of the bubble, which results the photo width if
    // there's no quoted message, or the whole bubble width if there is.
    static let bubbleWidth: CGFloat = 220
    
    override class var supportsQuoting: Bool {
        true
    }
    
    override class var quotedMessageMargin: Margin {
        Margin(leading: 11, trailing: 4, top: 3, bottom: 0)
    }
    
    let contentRatio: CGSize
    
    var photoFrame = CGRect.zero
    var trailingInfoBackgroundFrame = CGRect.zero
    var operationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)
    var layoutPosition = VerticalPositioningImageView.Position.center
    
    override var contentMargin: Margin {
        return Margin(leading: 9, trailing: 5, top: 4, bottom: 6)
    }
    
    override var statusNormalTintColor: UIColor {
        return .white
    }
    
    private var maxPresentationHeight: CGFloat {
        return performSynchronouslyOnMainThread {
            AppDelegate.current.window.bounds.height / 2
        }
    }
    
    private var fullnameHeight: CGFloat {
        style.contains(.fullname) ? fullnameFrame.height : 0
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
    
    override func quoteViewLayoutWidth(from width: CGFloat) -> CGFloat {
        Self.bubbleWidth - Self.quotedMessageMargin.horizontal
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        
        let ratio = contentRatio.width / contentRatio.height
        if quotedMessageViewModel == nil {
            let photoHeight = min(maxPresentationHeight, round(Self.bubbleWidth / ratio))
            photoFrame.size = CGSize(width: Self.bubbleWidth, height: photoHeight)
        } else {
            let photoWidth = Self.bubbleWidth - Self.quotingMessageMargin.horizontal
            let photoHeight = min(maxPresentationHeight, round(photoWidth / ratio))
            photoFrame.size = CGSize(width: photoWidth, height: photoHeight)
        }
        
        let bubbleOrigin: CGPoint
        if style.contains(.received) {
            if style.contains(.fullname) {
                bubbleOrigin = CGPoint(x: Self.bubbleMargin.leading,
                                       y: Self.bubbleMargin.top + fullnameHeight)
            } else {
                bubbleOrigin = CGPoint(x: Self.bubbleMargin.leading,
                                       y: Self.bubbleMargin.top)
            }
        } else {
            bubbleOrigin = CGPoint(x: width - Self.bubbleMargin.leading - Self.bubbleWidth,
                                   y: Self.bubbleMargin.top)
        }
        
        
        if let quotedMessageViewModel = quotedMessageViewModel {
            let x: CGFloat
            if style.contains(.received) {
                x = bubbleOrigin.x + Self.quotingMessageMargin.trailing
            } else {
                x = bubbleOrigin.x + Self.quotingMessageMargin.leading
            }
            let y = bubbleOrigin.y
                + Self.quotedMessageMargin.top
                + quotedMessageViewModel.contentSize.height
                + Self.quotingMessageMargin.top
            photoFrame.origin = CGPoint(x: x, y: y)
            
            let backgroundHeight = Self.quotedMessageMargin.vertical
                + quotedMessageViewModel.contentSize.height
                + Self.quotingMessageMargin.vertical
                + photoFrame.height
            let backgroundSize = CGSize(width: Self.bubbleWidth, height: backgroundHeight)
            backgroundImageFrame = CGRect(origin: bubbleOrigin, size: backgroundSize)
        } else {
            photoFrame.origin = bubbleOrigin
            backgroundImageFrame = photoFrame
        }
        
        cellHeight = fullnameHeight + backgroundImageFrame.height + bottomSeparatorHeight
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        layoutTrailingInfoBackgroundFrame()
        layoutQuotedMessageIfPresent()
    }
    
    func update(mediaUrl: String?, mediaSize: Int64?, mediaDuration: Int64?) {
        message.mediaUrl = mediaUrl
        message.mediaSize = mediaSize
        message.mediaDuration = mediaDuration
    }
    
}
