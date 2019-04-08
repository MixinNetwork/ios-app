import UIKit

class CardMessageViewModel: DetailInfoMessageViewModel {
    
    var leadingConstant: CGFloat = 0
    var trailingConstant: CGFloat = 0
    
    override class var bubbleImageProvider: BubbleImageProvider.Type {
        return LightRightBubbleImageProvider.self
    }
    
    var fullnameHeight: CGFloat {
        return style.contains(.fullname) ? fullnameFrame.height : 0
    }
    
    internal var size: CGSize {
        return CGSize(width: 220, height: 72)
    }
    
    internal var leftLeadingMargin: CGFloat {
        return 22
    }
    
    internal var rightLeadingMargin: CGFloat {
        return 12
    }
    
    internal var leftTrailingMargin: CGFloat {
        return 20
    }
    
    internal var rightTrailingMargin: CGFloat {
        return 30
    }
    
    override func didSetStyle() {
        let backgroundSize = CGSize(width: min(size.width, layoutWidth - MessageViewModel.backgroundImageMargin.horizontal),
                                    height: size.height)
        let backgroundOrigin: CGPoint
        if style.contains(.received) {
            backgroundOrigin = CGPoint(x: MessageViewModel.backgroundImageMargin.leading, y: fullnameHeight)
            leadingConstant = leftLeadingMargin
            trailingConstant = leftTrailingMargin
        } else {
            backgroundOrigin = CGPoint(x: layoutWidth - MessageViewModel.backgroundImageMargin.leading - backgroundSize.width, y: fullnameHeight)
            leadingConstant = rightLeadingMargin
            trailingConstant = rightTrailingMargin
        }
        backgroundImageFrame = CGRect(origin: backgroundOrigin, size: backgroundSize)
        cellHeight = fullnameHeight + backgroundSize.height + bottomSeparatorHeight
        super.didSetStyle()
    }
    
}
