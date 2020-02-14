import UIKit
import MixinServices

class AppCardMessageViewModel: CardMessageViewModel, TitledCardContentWidthCalculable {
    
    static let titleFontSet = MessageFontSet(style: .body)
    static let descriptionFontSet = MessageFontSet(size: 14, weight: .regular)
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return AppCardBubbleImageSet.self
    }
    
    override class var leftViewSideLength: CGFloat {
        48
    }
    
    override func layout(width: CGFloat, style: Style) {
        updateContentWidth(title: message.appCard?.title,
                           titleFont: Self.titleFontSet.scaled,
                           subtitle: message.appCard?.description,
                           subtitleFont: Self.descriptionFontSet.scaled)
        super.layout(width: width, style: style)
    }
    
}
