import UIKit
import MixinServices

class AppCardMessageViewModel: CardMessageViewModel, TitledCardContentWidthCalculable {
        
    override class var bubbleImageSet: BubbleImageSet.Type {
        return AppCardBubbleImageSet.self
    }
    
    override class var leftViewSideLength: CGFloat {
        48
    }
    
    override func layout(width: CGFloat, style: Style) {
        updateContentWidth(title: message.appCard?.title,
                           titleFont: MessageFontSet.cardTitle.scaled,
                           subtitle: message.appCard?.description,
                           subtitleFont: MessageFontSet.cardSubtitle.scaled)
        super.layout(width: width, style: style)
    }
    
}
