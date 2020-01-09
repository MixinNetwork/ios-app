import UIKit

class LiveMessageViewModel: PhotoRepresentableMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return LightRightBubbleImageSet.self
    }
    
    var badgeOrigin = CGPoint.zero
    
    private let badgeMargin = Margin(leading: 12, trailing: 4, top: 3, bottom: 0)
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        if style.contains(.received) {
            badgeOrigin = CGPoint(x: presentationFrame.origin.x + badgeMargin.leading,
                                  y: presentationFrame.origin.y + badgeMargin.top)
        } else {
            badgeOrigin = CGPoint(x: presentationFrame.origin.x + badgeMargin.trailing,
                                  y: presentationFrame.origin.y + badgeMargin.top)
        }
    }
    
}
