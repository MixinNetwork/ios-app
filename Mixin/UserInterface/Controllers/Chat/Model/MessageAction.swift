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
            return R.string.localizable.reply()
        case .forward:
            return R.string.localizable.forward()
        case .copy:
            return R.string.localizable.copy()
        case .delete:
            return R.string.localizable.delete()
        case .addToStickers:
            return R.string.localizable.add_to_Stickers()
        case .report:
            return R.string.localizable.report()
        case .pin:
            return R.string.localizable.pin_title()
        case .unpin:
            return R.string.localizable.unpin()
            
        }
    }
    
}
