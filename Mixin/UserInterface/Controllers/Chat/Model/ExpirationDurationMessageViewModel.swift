import UIKit
import MixinServices

final class ExpirationDurationMessageViewModel: SystemMessageViewModel {
    
    enum Kind {
        case conversationHint(isGroup: Bool)
        case settingChange
    }
    
    let expirationDuration: Int64
    
    private let kind: Kind
    
    init(message: MessageItem, kind: Kind, canEditExpiration: Bool) {
        self.kind = kind
        switch kind {
        case .conversationHint:
            expirationDuration = message.expireIn ?? 0
        case .settingChange:
            expirationDuration = message.content?.int64Value ?? 0
        }
        super.init(message: message, text: "")
        backgroundImage = expirationDuration > 0
            ? R.image.chat_bubble_purple()
            : R.image.chat_bubble_gray()
        update(canEditExpiration: canEditExpiration)
    }
    
    func update(canEditExpiration: Bool) {
        switch kind {
        case .conversationHint(let isGroup):
            if expirationDuration > 0 {
                let duration = ExpiredMessageDurationFormatter.string(from: expirationDuration)
                if isGroup {
                    text = canEditExpiration
                        ? R.string.localizable.group_disappearing_message_enabled_editable(duration)
                        : R.string.localizable.group_disappearing_message_enabled_read_only(duration)
                } else {
                    text = R.string.localizable.chat_disappearing_message_enabled_editable(duration)
                }
            } else {
                if isGroup {
                    text = canEditExpiration
                        ? R.string.localizable.group_disappearing_message_disabled_editable()
                        : R.string.localizable.group_disappearing_message_disabled_read_only()
                } else {
                    text = R.string.localizable.chat_disappearing_message_disabled_editable()
                }
            }
            message.content = text
        case .settingChange:
            text = SystemConversationAction.getSystemMessage(
                actionName: message.actionName,
                userId: message.userId,
                userFullName: message.userFullName ?? "",
                participantId: message.participantUserId,
                participantFullName: message.participantFullName,
                content: message.content,
                style: canEditExpiration ? .editable : .readOnly,
            )
        }
        layout(width: layoutWidth, style: style)
    }
    
}
