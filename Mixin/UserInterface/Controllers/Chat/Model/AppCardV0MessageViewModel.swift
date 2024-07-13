import UIKit
import MixinServices

final class AppCardV0MessageViewModel: CardMessageViewModel, TitledCardContentWidthCalculable {
    
    let content: AppCardData.V0Content?
    
    init(message: MessageItem, content: AppCardData.V0Content?) {
        self.content = content
        super.init(message: message)
    }
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return AppCardBubbleImageSet.self
    }
    
    override class var leftViewSideLength: CGFloat {
        48
    }
    
    override func layout(width: CGFloat, style: Style) {
        let title, subtitle: String?
        switch message.appCard {
        case .v0(let content):
            (title, subtitle) = (content.title, content.description)
        case .v1(let content):
            assertionFailure("Use V1")
            (title, subtitle) = (content.title, content.description)
        case .none:
            (title, subtitle) = (nil, nil)
        }
        updateContentWidth(title: title,
                           titleFont: MessageFontSet.cardTitle.scaled,
                           subtitle: subtitle,
                           subtitleFont: MessageFontSet.cardSubtitle.scaled)
        super.layout(width: width, style: style)
    }
    
}
