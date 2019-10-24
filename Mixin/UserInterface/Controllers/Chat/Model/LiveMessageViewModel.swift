import UIKit

class LiveMessageViewModel: PhotoRepresentableMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return LightRightBubbleImageSet.self
    }
    
    private let badgeMargin = Margin(leading: 12, trailing: 4, top: 3, bottom: 0)
    
    var badgeOrigin = CGPoint.zero
    
    override func layout() {
        super.layout()
        if style.contains(.received) {
            badgeOrigin = CGPoint(x: contentFrame.origin.x + badgeMargin.leading,
                                  y: contentFrame.origin.y + badgeMargin.top)
        } else {
            badgeOrigin = CGPoint(x: contentFrame.origin.x + badgeMargin.trailing,
                                  y: contentFrame.origin.y + badgeMargin.top)
        }
    }
    
}
