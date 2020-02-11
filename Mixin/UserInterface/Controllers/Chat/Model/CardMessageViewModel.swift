import UIKit

class CardMessageViewModel: DetailInfoMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return LightRightBubbleImageSet.self
    }
    
    override class var quotedMessageMargin: Margin {
        Margin(leading: 9, trailing: 2, top: 1, bottom: 0)
    }
    
    private(set) var leadingConstant: CGFloat = 0
    private(set) var trailingConstant: CGFloat = 0
    
    var fullnameHeight: CGFloat {
        return style.contains(.fullname) ? fullnameFrame.height : 0
    }
    
    var contentWidth: CGFloat {
        220
    }
    
    var receivedLeadingMargin: CGFloat {
        return 22
    }
    
    var receivedTrailingMargin: CGFloat {
        return 20
    }
    
    var sentLeadingMargin: CGFloat {
        return 12
    }
    
    var sentTrailingMargin: CGFloat {
        return 30
    }
    
    private var contentHeight: CGFloat {
        var height: CGFloat = 72
        if let viewModel = quotedMessageViewModel {
            height += Self.quotedMessageMargin.vertical + viewModel.contentSize.height
        }
        return height
    }
    
    override func quoteViewLayoutWidth(from width: CGFloat) -> CGFloat {
        contentWidth - Self.quotedMessageMargin.horizontal
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        let bubbleMargin = DetailInfoMessageViewModel.bubbleMargin
        let backgroundSize = CGSize(width: min(contentWidth, width - bubbleMargin.horizontal),
                                    height: contentHeight)
        let backgroundOrigin: CGPoint
        if style.contains(.received) {
            backgroundOrigin = CGPoint(x: bubbleMargin.leading, y: fullnameHeight)
            leadingConstant = receivedLeadingMargin
            trailingConstant = receivedTrailingMargin
        } else {
            backgroundOrigin = CGPoint(x: width - bubbleMargin.leading - backgroundSize.width, y: fullnameHeight)
            leadingConstant = sentLeadingMargin
            trailingConstant = sentTrailingMargin
        }
        backgroundImageFrame = CGRect(origin: backgroundOrigin, size: backgroundSize)
        cellHeight = fullnameHeight + backgroundSize.height + timeFrame.height + timeMargin.bottom + bottomSeparatorHeight
        layoutDetailInfo(insideBackgroundImage: false, backgroundImageFrame: backgroundImageFrame)
        layoutQuotedMessageIfPresent()
    }
    
}
