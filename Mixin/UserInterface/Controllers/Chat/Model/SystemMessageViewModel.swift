import UIKit

class SystemMessageViewModel: MessageViewModel {
    
    enum LabelInsets {
        static let horizontal: CGFloat = 16
        static let vertical: CGFloat = 16
    }
    
    private static let attributes: [NSAttributedString.Key: Any] = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        return [.font: UIFont.systemFont(ofSize: 14),
                .paragraphStyle: paragraphStyle]
    }()
    
    let text: String
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        text = SystemConversationAction.getSystemMessage(actionName: message.actionName,
                                                         userId: message.userId,
                                                         userFullName: message.userFullName,
                                                         participantId: message.participantUserId,
                                                         participantFullName: message.participantFullName,
                                                         content: message.content)
        super.init(message: message, style: style, fits: layoutWidth)
        backgroundImage = R.image.ic_chat_bubble_system()
    }
    
    override func layout() {
        let backgroundImageHorizontalMargin: CGFloat = 76
        let sizeToFit = CGSize(width: layoutWidth - backgroundImageHorizontalMargin,
                               height: UIView.layoutFittingExpandedSize.height)
        let textRect = (text as NSString).boundingRect(with: sizeToFit,
                                                       options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                       attributes: SystemMessageViewModel.attributes,
                                                       context: nil)
        super.layout()
        cellHeight = textRect.height
            + LabelInsets.vertical
            + bottomSeparatorHeight
    }
    
}
