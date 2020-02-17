import UIKit
import MixinServices

class ConversationInputTextView: UITextView {
    
    weak var overrideNext: UIResponder?
    
    override var next: UIResponder? {
        if let responder = overrideNext {
            return responder
        } else {
            return super.next
        }
    }
    
    // Return the token between Mention.prefix and the caret
    // token is separated with space
    var inputingMentionTokenRange: NSRange? {
        guard !text.isEmpty else {
            return nil
        }
        guard let selectedTextRange = selectedTextRange else {
            return nil
        }
        guard let rangeBeforeCaret = textRange(from: beginningOfDocument, to: selectedTextRange.start) else {
            return nil
        }
        guard let stringBeforeCaret = text(in: rangeBeforeCaret) else {
            return nil
        }
        for (index, char) in stringBeforeCaret.enumerated().reversed() {
            if char == " " {
                return nil
            } else if char == Mention.prefix {
                let start = stringBeforeCaret.index(stringBeforeCaret.startIndex, offsetBy: index.advanced(by: 1))
                let end = stringBeforeCaret.endIndex
                return NSRange(start..<end, in: stringBeforeCaret)
            }
        }
        return nil
    }
    
    var inputingMentionToken: String? {
        if let range = inputingMentionTokenRange {
            return (text as NSString).substring(with: range)
        } else {
            return nil
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if overrideNext != nil {
            return false
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    func replaceInputingMentionToken(with user: UserItem) -> NSRange? {
        let replacement = "\(Mention.prefix)\(user.identityNumber)\(Mention.suffix)"
        guard !text.isEmpty else {
            text = replacement
            return nil
        }
        guard let selectedTextRange = selectedTextRange else {
            return nil
        }
        guard let rangeBeforeCaret = textRange(from: beginningOfDocument, to: selectedTextRange.start) else {
            return nil
        }
        guard let stringBeforeCaret = text(in: rangeBeforeCaret) else {
            return nil
        }
        for (index, char) in stringBeforeCaret.reversed().enumerated() {
            if char == " " {
                return nil
            } else if char == Mention.prefix {
                guard let start = position(from: rangeBeforeCaret.end, offset: -index - 1), let range = textRange(from: start, to: rangeBeforeCaret.end) else {
                    return nil
                }
                replace(range, withText: replacement)
                let replacementRange = NSRange(location: offset(from: beginningOfDocument, to: range.start),
                                               length: (replacement as NSString).length - 1)
                let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
                mutable.addAttributes([.foregroundColor: UIColor.theme], range: replacementRange)
                attributedText = (mutable.copy() as! NSAttributedString)
                return replacementRange
            }
        }
        return nil
    }
    
}
