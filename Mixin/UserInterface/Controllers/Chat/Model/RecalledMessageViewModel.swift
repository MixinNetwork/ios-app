import UIKit

class RecalledMessageViewModel: IconPrefixedTextMessageViewModel {
    
    private enum Font {
        private static let font: UIFont = {
            let descriptor = UIFont.systemFont(ofSize: 16).fontDescriptor.withMatrix(.italic)
            return UIFont(descriptor: descriptor, size: 16)
        }()
        static let ctFont = CTFontCreateWithFontDescriptor(font.fontDescriptor as CTFontDescriptor, 0, nil)
        static let lineHeight = round(font.lineHeight)
    }
    
    override class var ctFont: CTFont {
        return Font.ctFont
    }
    
    override class var lineHeight: CGFloat {
        return Font.lineHeight
    }
    
    override var rawContent: String {
        let isRecalledByRemote = message.userId != AccountAPI.shared.accountUserId
        if isRecalledByRemote {
            return R.string.localizable.chat_message_recalled()
        } else {
            return R.string.localizable.chat_message_recalled_by_me()
        }
    }
    
    override var showStatusImage: Bool {
        return false
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        if style.contains(.received) {
            prefixImage = R.image.ic_recalled_message_prefix_received()
        } else {
            prefixImage = R.image.ic_recalled_message_prefix_sent()
        }
    }
    
}
