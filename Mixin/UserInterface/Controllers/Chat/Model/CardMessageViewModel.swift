import UIKit

class CardMessageViewModel: DetailInfoMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return LightRightBubbleImageSet.self
    }
    
    private(set) var leadingConstant: CGFloat = 0
    private(set) var trailingConstant: CGFloat = 0
    
    var fullnameHeight: CGFloat {
        return style.contains(.fullname) ? fullnameFrame.height : 0
    }
    
    var size: CGSize {
        return CGSize(width: 220, height: 72)
    }
    
    var leftLeadingMargin: CGFloat {
        return 22
    }
    
    var rightLeadingMargin: CGFloat {
        return 12
    }
    
    var leftTrailingMargin: CGFloat {
        return 20
    }
    
    var rightTrailingMargin: CGFloat {
        return 30
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        let bubbleMargin = DetailInfoMessageViewModel.bubbleMargin
        let backgroundSize = CGSize(width: min(size.width, width - bubbleMargin.horizontal),
                                    height: size.height)
        let backgroundOrigin: CGPoint
        if style.contains(.received) {
            backgroundOrigin = CGPoint(x: bubbleMargin.leading, y: fullnameHeight)
            leadingConstant = leftLeadingMargin
            trailingConstant = leftTrailingMargin
        } else {
            backgroundOrigin = CGPoint(x: width - bubbleMargin.leading - backgroundSize.width, y: fullnameHeight)
            leadingConstant = rightLeadingMargin
            trailingConstant = rightTrailingMargin
        }
        backgroundImageFrame = CGRect(origin: backgroundOrigin, size: backgroundSize)
        cellHeight = fullnameHeight + backgroundSize.height + bottomSeparatorHeight
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
    }
    
}
