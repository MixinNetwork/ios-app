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
        let uFullName = message.userId == myUserId ? R.string.localizable.chat_message_you() : (message.userFullName ?? "")
        var category = ""
        if let data = message.content?.data(using: .utf8), let localContent = try? JSONDecoder.default.decode(PinMessage.LocalContent.self, from: data) {
            if localContent.category.hasSuffix("_TEXT"), let content = localContent.content {
                message.content = content
            }
            category = localContent.category
        }
        text = TransferPinAction.getPinMessage(userId: message.userId, userFullName: uFullName, category: category, content: message.mentionedFullnameReplacedContent)
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
