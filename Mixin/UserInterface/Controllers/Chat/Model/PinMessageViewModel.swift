import UIKit
import MixinServices

class PinMessageViewModel: MessageViewModel {
    
    enum LabelInsets {
        static let horizontal: CGFloat = 16
        static let vertical: CGFloat = 16
    }
    
    private static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.alignment = .center
        return style.copy() as! NSParagraphStyle
    }()
    
    let text: String
    
    override init(message: MessageItem) {
        if let content = message.content {
            text = TransferPinAction.getPinMessage(userId: message.userId, userFullName: message.userFullName ?? "", content: content)
        } else {
            text = message.content ?? ""
        }
        super.init(message: message)
        backgroundImage = R.image.ic_chat_bubble_system()
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        cellHeight = MessageFontSet.systemMessage.scaled.lineHeight
            + LabelInsets.vertical
            + bottomSeparatorHeight
    }
    
}
