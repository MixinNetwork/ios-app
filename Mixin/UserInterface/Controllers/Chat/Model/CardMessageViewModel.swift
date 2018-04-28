import UIKit

class CardMessageViewModel: DetailInfoMessageViewModel {
    
    static let leftLeadingMargin: CGFloat = 22
    static let rightLeadingMargin: CGFloat = 12
    static let leftTrailingMargin: CGFloat = -20
    static let rightTrailingMargin: CGFloat = -30
    
    internal(set) var leadingConstant: CGFloat = 0
    internal(set) var trailingConstant: CGFloat = 0
    
    var fullnameHeight: CGFloat {
        return style.contains(.showFullname) ? fullnameFrame.height : 0
    }
    
    internal var size: CGSize {
        return CGSize(width: 220, height: 72)
    }

    override var rightBubbleImage: UIImage {
        return #imageLiteral(resourceName: "ic_transfer_bubble_right")
    }
    
    override var rightWithTailBubbleImage: UIImage {
        return #imageLiteral(resourceName: "ic_transfer_bubble_right_tail")
    }
    
    override func didSetStyle() {
        let backgroundOrigin: CGPoint
        if style.contains(.received) {
            backgroundOrigin = CGPoint(x: MessageViewModel.backgroundImageMargin.leading, y: fullnameHeight)
            leadingConstant = TransferMessageViewModel.leftLeadingMargin
            trailingConstant = TransferMessageViewModel.leftTrailingMargin
        } else {
            backgroundOrigin = CGPoint(x: layoutWidth - MessageViewModel.backgroundImageMargin.leading - size.width, y: fullnameHeight)
            leadingConstant = TransferMessageViewModel.rightLeadingMargin
            trailingConstant = TransferMessageViewModel.rightTrailingMargin
        }
        backgroundImageFrame = CGRect(origin: backgroundOrigin, size: size)
        cellHeight = fullnameHeight + size.height + bottomSeparatorHeight
        super.didSetStyle()
    }
    
}
