import Foundation

enum MessageAction {
    
    case reply
    case forward
    case copy
    case delete
    case addToStickers
    case report
    case pin
    case unpin
    
    var image: UIImage? {
        switch self {
        case .reply:
            return R.image.conversation.ic_action_reply()
        case .forward:
            return R.image.conversation.ic_action_forward()
        case .copy:
            return R.image.conversation.ic_action_copy()
        case .delete:
            return R.image.conversation.ic_action_delete()
        case .addToStickers:
            return R.image.conversation.ic_action_add_to_sticker()
        case .report:
            return R.image.conversation.ic_action_report()
        case .pin:
            return R.image.conversation.ic_action_pin()
        case .unpin:
            return R.image.conversation.ic_action_unpin()
        }
    }
    
    var title: String {
        switch self {
        case .reply:
            return R.string.localizable.chat_message_menu_reply()
        case .forward:
            return R.string.localizable.chat_message_menu_forward()
        case .copy:
            return R.string.localizable.chat_message_menu_copy()
        case .delete:
            return R.string.localizable.menu_delete()
        case .addToStickers:
            return R.string.localizable.chat_message_sticker()
        case .report:
            return R.string.localizable.menu_report()
        case .pin:
            return R.string.localizable.menu_pin()
        case .unpin:
            return R.string.localizable.menu_unpin()
            
        }
    }
    
}
