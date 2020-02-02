import UIKit
import MixinServices

class SystemMessageViewModel: MessageViewModel {
    
    enum LabelInsets {
        static let horizontal: CGFloat = 16
        static let vertical: CGFloat = 16
    }
    
    private static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        return style.copy() as! NSParagraphStyle
    }()
    
    let text: String
    
    override init(message: MessageItem) {
        text = SystemConversationAction.getSystemMessage(actionName: message.actionName,
                                                         userId: message.userId,
                                                         userFullName: message.userFullName,
                                                         participantId: message.participantUserId,
                                                         participantFullName: message.participantFullName,
                                                         content: message.content)
        super.init(message: message)
        backgroundImage = R.image.ic_chat_bubble_system()
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        let backgroundImageHorizontalMargin: CGFloat = 76
        let sizeToFit = CGSize(width: width - backgroundImageHorizontalMargin,
                               height: UIView.layoutFittingExpandedSize.height)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: MessageFontSet.systemMessage.scaled,
            .paragraphStyle: SystemMessageViewModel.paragraphStyle
        ]
        let textRect = (text as NSString).boundingRect(with: sizeToFit,
                                                       options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                       attributes: attrs,
                                                       context: nil)
        super.layout(width: width, style: style)
        cellHeight = textRect.height
            + LabelInsets.vertical
            + bottomSeparatorHeight
    }
    
}
