import UIKit

class UnknownMessageViewModel: TextMessageViewModel {
    
    override class var textColor: UIColor {
        return .white
    }
    
    override class var bubbleImageProvider: BubbleImageProvider.Type {
        return UnknownBubbleImageProvider.self
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        message.content = Localized.CHAT_CELL_TITLE_UNKNOWN_CATEGORY
        super.init(message: message, style: style, fits: layoutWidth)
        statusImage = nil
    }
    
}

extension UnknownMessageViewModel {
    
    class UnknownBubbleImageProvider: BubbleImageProvider {
        
        override class var left: UIImage {
            return R.image.ic_chat_bubble_unknown_left()!
        }
        
        override class var leftTail: UIImage {
            return R.image.ic_chat_bubble_unknown_left_tail()!
        }
        
    }
    
}
