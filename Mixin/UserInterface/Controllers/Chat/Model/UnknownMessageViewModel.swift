import UIKit

class UnknownMessageViewModel: TextMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return UnknownBubbleImageSet.self
    }
    
    override class var textColor: UIColor {
        return .white
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        message.content = Localized.CHAT_CELL_TITLE_UNKNOWN_CATEGORY
        super.init(message: message, style: style, fits: layoutWidth)
        statusImage = nil
    }
    
}
