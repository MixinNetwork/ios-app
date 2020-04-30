import Foundation

enum MessageAction {
    
    case reply
    case forward
    case copy
    case delete
    case addToStickers
    case report
    
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
        }
    }
    
}
