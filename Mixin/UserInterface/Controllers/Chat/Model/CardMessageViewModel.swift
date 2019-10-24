import UIKit

class CardMessageViewModel: DetailInfoMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return LightRightBubbleImageSet.self
    }
    
    var leadingConstant: CGFloat = 0
    var trailingConstant: CGFloat = 0
    
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
    
    override func layout() {
        let bubbleMargin = DetailInfoMessageViewModel.bubbleMargin
        let backgroundSize = CGSize(width: min(size.width, layoutWidth - bubbleMargin.horizontal),
                                    height: size.height)
        let backgroundOrigin: CGPoint
        if style.contains(.received) {
            backgroundOrigin = CGPoint(x: bubbleMargin.leading, y: fullnameHeight)
            leadingConstant = leftLeadingMargin
            trailingConstant = leftTrailingMargin
        } else {
            backgroundOrigin = CGPoint(x: layoutWidth - bubbleMargin.leading - backgroundSize.width, y: fullnameHeight)
            leadingConstant = rightLeadingMargin
            trailingConstant = rightTrailingMargin
        }
        backgroundImageFrame = CGRect(origin: backgroundOrigin, size: backgroundSize)
        cellHeight = fullnameHeight + backgroundSize.height + bottomSeparatorHeight
        super.layout()
    }
    
}
