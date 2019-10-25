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
        let textRect = (text as NSString).boundingRect(with: sizeToFit,
                                                       options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                       attributes: SystemMessageViewModel.attributes,
                                                       context: nil)
        super.layout(width: width, style: style)
        cellHeight = textRect.height
            + LabelInsets.vertical
            + bottomSeparatorHeight
    }
    
}
