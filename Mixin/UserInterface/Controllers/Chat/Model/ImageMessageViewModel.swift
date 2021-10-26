import UIKit

class ImageMessageViewModel: DetailInfoMessageViewModel, BackgroundedTrailingInfoViewModel {
    
    static let quotingMessageMargin = Margin(leading: 4, trailing: 11, top: 2, bottom: 5)
    
    override class var supportsQuoting: Bool {
        true
    }
    
    override class var quotedMessageMargin: Margin {
        Margin(leading: 11, trailing: 4, top: 3, bottom: 0)
    }
    
    var photoFrame = CGRect.zero
    var trailingInfoBackgroundFrame = CGRect.zero
    
    override var contentMargin: Margin {
        return Margin(leading: 9, trailing: 5, top: 4, bottom: 6)
    }
    
    override var statusNormalTintColor: UIColor {
        return .white
    }
    
    override var trailingInfoColor: UIColor {
        .white
    }
    
    var fullnameHeight: CGFloat {
        style.contains(.fullname) ? fullnameFrame.height : 0
    }
    
    override func quoteViewLayoutWidth(from width: CGFloat) -> CGFloat {
        photoFrame.width
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
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
            let x: CGFloat
            if quotedMessageViewModel == nil {
                x = width - Self.bubbleMargin.leading - photoFrame.width
            } else {
                x = width - Self.bubbleMargin.leading - photoFrame.width - Self.quotingMessageMargin.horizontal
            }
            bubbleOrigin = CGPoint(x: x, y: Self.bubbleMargin.top)
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
            let backgroundWidth = photoFrame.width + Self.quotingMessageMargin.horizontal
            let backgroundSize = CGSize(width: backgroundWidth, height: backgroundHeight)
            backgroundImageFrame = CGRect(origin: bubbleOrigin, size: backgroundSize)
        } else {
            photoFrame.origin = bubbleOrigin
            backgroundImageFrame = photoFrame
        }
        
        cellHeight = fullnameHeight + backgroundImageFrame.height + bottomSeparatorHeight
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        layoutQuotedMessageIfPresent()
    }
    
}
