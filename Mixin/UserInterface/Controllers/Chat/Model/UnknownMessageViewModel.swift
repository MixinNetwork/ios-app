import UIKit

class UnknownMessageViewModel: TextMessageViewModel {
    
    override class var textColor: UIColor {
        return .white
    }
    
    override var leftBubbleImage: UIImage {
        return #imageLiteral(resourceName: "ic_chat_bubble_unknown_left")
    }
    
    override var leftWithTailBubbleImage: UIImage {
        return #imageLiteral(resourceName: "ic_chat_bubble_unknown_left_tail")
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        message.content = Localized.CHAT_CELL_TITLE_UNKNOWN_CATEGORY
        super.init(message: message, style: style, fits: layoutWidth)
        statusImage = nil
    }
    
}
