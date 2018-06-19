import UIKit

class UnknownMessageViewModel: TextMessageViewModel {

    private static let leftWithTailBubbleImage = #imageLiteral(resourceName: "ic_chat_bubble_unknown_left_tail")
    private static let leftBubbleImage = #imageLiteral(resourceName: "ic_chat_bubble_unknown_left")
    
    override var textColor: UIColor {
        return .white
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        message.content = Localized.CHAT_CELL_TITLE_UNKNOWN_CATEGORY
        super.init(message: message, style: style, fits: layoutWidth)
        statusImage = nil
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        if style.contains(.tail) {
            backgroundImage = UnknownMessageViewModel.leftWithTailBubbleImage
        } else {
            backgroundImage = UnknownMessageViewModel.leftWithTailBubbleImage
        }
    }
    
}
