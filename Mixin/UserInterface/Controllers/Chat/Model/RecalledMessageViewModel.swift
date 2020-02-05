import UIKit
import MixinServices

class RecalledMessageViewModel: IconPrefixedTextMessageViewModel {
    
    private static let normalFont: UIFont = {
        let size: CGFloat = 16
        let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withMatrix(.italic)
        return UIFont(descriptor: descriptor, size: size)
    }()
    
    override class var font: UIFont {
        UIFontMetrics.default.scaledFont(for: normalFont)
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
