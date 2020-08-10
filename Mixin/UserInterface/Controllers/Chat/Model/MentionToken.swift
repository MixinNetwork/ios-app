import Foundation

extension NSAttributedString.Key {
    
    public static let mentionToken = NSAttributedString.Key(rawValue: "one.mixin.messenger.MentionToken")
    
}

struct MentionToken {
    
    let id = UUID()
    let length: Int
    
    init(length: Int) {
        self.length = length
    }
    
}
