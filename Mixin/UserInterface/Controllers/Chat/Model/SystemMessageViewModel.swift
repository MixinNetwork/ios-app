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
        style.alignment = .center
        return style.copy() as! NSParagraphStyle
    }()
    
    let text: String
    
    override init(message: MessageItem) {
        let senderIsMe = message.userId == myUserId
        let senderName = senderIsMe ? R.string.localizable.chat_message_you() : (message.userFullName ?? "")
        if message.category == MessageCategory.KRAKEN_PUBLISH.rawValue {
            text = R.string.localizable.group_call_publish(senderName)
        } else if message.category == MessageCategory.KRAKEN_CANCEL.rawValue {
            text = R.string.localizable.group_call_cancel(senderName)
        } else if message.category == MessageCategory.KRAKEN_DECLINE.rawValue {
            text = R.string.localizable.group_call_decline(senderName)
        } else if message.category == MessageCategory.KRAKEN_INVITE.rawValue {
            text = R.string.localizable.group_call_invite(senderName)
        } else if message.category == MessageCategory.KRAKEN_END.rawValue {
            let mediaDuration = Double(message.mediaDuration ?? 0) / millisecondsPerSecond
            let duration = CallDurationFormatter.string(from: mediaDuration) ?? "0"
            text = R.string.localizable.group_call_end_duration(duration)
        } else {
            text = SystemConversationAction.getSystemMessage(actionName: message.actionName,
                                                             userId: message.userId,
                                                             userFullName: message.userFullName ?? "",
                                                             participantId: message.participantUserId,
                                                             participantFullName: message.participantFullName,
                                                             content: message.content ?? "")
        }
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
