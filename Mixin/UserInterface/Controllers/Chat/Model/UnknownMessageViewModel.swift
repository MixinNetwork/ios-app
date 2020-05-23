import UIKit
import MixinServices

class UnknownMessageViewModel: TextMessageViewModel {
    
    override var rawContent: String {
        Localized.CHAT_CELL_TITLE_UNKNOWN_CATEGORY
            + R.string.localizable.chat_sentence_learn_more()
    }
    
    override init(message: MessageItem) {
        super.init(message: message)
        statusImage = nil
    }
    
    override func linkRanges(from string: String) -> [Link.Range] {
        let location = (Localized.CHAT_CELL_TITLE_UNKNOWN_CATEGORY as NSString).length
        let length = (R.string.localizable.chat_sentence_learn_more() as NSString).length
        let range = NSRange(location: location, length: length)
        return [Link.Range(range: range, url: .unknownCategory)]
    }
    
}
