import UIKit

class RecalledMessageViewModel: IconPrefixedTextMessageViewModel {
    
    override class var ctFont: CTFont {
        return CoreTextFontSet.recalledMessage.ctFont
    }
    
    override class var lineHeight: CGFloat {
        return CoreTextFontSet.recalledMessage.lineHeight
    }
    
    override var rawContent: String {
        let isRecalledByRemote = message.userId != myUserId
        if isRecalledByRemote {
            return R.string.localizable.chat_message_recalled()
        } else {
            return R.string.localizable.chat_message_recalled_by_me()
        }
    }
    
    override var showStatusImage: Bool {
        return false
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        if style.contains(.received) {
            prefixImage = R.image.ic_recalled_message_prefix_received()
        } else {
            prefixImage = R.image.ic_recalled_message_prefix_sent()
        }
    }
    
}
