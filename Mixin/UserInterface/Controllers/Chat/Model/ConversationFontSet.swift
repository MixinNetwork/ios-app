import UIKit

class ConversationFontSet: PresentationFontSize {
    
    static let normalContent = ConversationFontSet(size: 14, weight: .regular)
    static let recalledContent: ConversationFontSet = {
        let descriptor = UIFont.systemFont(ofSize: 14)
            .fontDescriptor
            .withMatrix(.italic)
        let font = UIFont(descriptor: descriptor, size: 14)
        return ConversationFontSet(font: font)
    }()
    
}
