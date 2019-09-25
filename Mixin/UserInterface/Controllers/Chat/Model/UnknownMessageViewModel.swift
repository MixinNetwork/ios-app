import UIKit

class UnknownMessageViewModel: TextMessageViewModel {
    
    override class var bubbleImageProvider: BubbleImageProvider.Type {
        return UnknownBubbleImageProvider.self
    }
    
    override var rawContent: String {
        return Localized.CHAT_CELL_TITLE_UNKNOWN_CATEGORY
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        super.init(message: message, style: style, fits: layoutWidth)
        statusImage = nil
    }
    
}

extension UnknownMessageViewModel {
    
    class UnknownBubbleImageProvider: BubbleImageProvider {
        
        override class var left: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_unknown_left")
        }
        
        override class var leftTail: UIImage {
            return #imageLiteral(resourceName: "ic_chat_bubble_unknown_left_tail")
        }
        
    }
    
}
