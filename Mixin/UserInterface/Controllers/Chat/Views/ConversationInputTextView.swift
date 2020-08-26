import UIKit
import MixinServices

class ConversationInputTextView: UITextView {
    
    weak var overrideNext: UIResponder?
    
    private(set) var isFloatingCursor = false
    private(set) var isFloatingCursorGoingForward = false
    private(set) var isFloatingCursorGoingBackward = false
    
    override var next: UIResponder? {
        if let responder = overrideNext {
            return responder
        } else {
            return super.next
        }
    }
    
    // Return the token from Mention.prefix to the caret
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
                let start = stringBeforeCaret.index(stringBeforeCaret.startIndex, offsetBy: index)
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
    
    func replaceInputingMentionToken(with user: UserItem) {
        let replacement = "\(Mention.prefix)\(user.identityNumber)\(Mention.suffix)"
        guard !text.isEmpty else {
            text = replacement
            return
        }
        guard let selectedTextRange = selectedTextRange else {
            return
        }
        guard let rangeBeforeCaret = textRange(from: beginningOfDocument, to: selectedTextRange.start) else {
            return
        }
        guard let stringBeforeCaret = text(in: rangeBeforeCaret) else {
            return
        }
        for (index, char) in stringBeforeCaret.reversed().enumerated() {
            if char == " " {
                return
            } else if char == Mention.prefix {
                guard let start = position(from: rangeBeforeCaret.end, offset: -index - 1) else {
                    return
                }
                let replacedRange = NSRange(location: offset(from: beginningOfDocument, to: start),
                                            length: index + 1)
                let mutable = NSMutableAttributedString(attributedString: attributedText)
                mutable.replaceCharacters(in: replacedRange, with: replacement)
                let replacementRange = NSRange(location: replacedRange.location,
                                               length: (replacement as NSString).length - 1) // 1 for the space after
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.theme,
                    .mentionToken: MentionToken(length: replacementRange.length)
                ]
                mutable.addAttributes(attrs, range: replacementRange)
                attributedText = NSAttributedString(attributedString: mutable)
                selectedRange = NSRange(location: NSMaxRange(replacementRange) + 1, length: 0) // 1 for the space after
                delegate?.textViewDidChange?(self)
                break
            }
        }
    }
    
    override func beginFloatingCursor(at point: CGPoint) {
        isFloatingCursor = true
        super.beginFloatingCursor(at: point)
    }
    
    override func updateFloatingCursor(at point: CGPoint) {
        defer {
            super.updateFloatingCursor(at: point)
        }
        let range = NSRange(location: 0, length: attributedText.length)
        let index = layoutManager.characterIndex(for: point,
                                                 in: textContainer,
                                                 fractionOfDistanceBetweenInsertionPoints: nil)
        let location = index - 1
        guard location >= 0 && location < attributedText.length else {
            return
        }
        var effectiveRange = NSRange(location: NSNotFound, length: 0)
        let token = attributedText.attribute(.mentionToken, at: location, longestEffectiveRange: &effectiveRange, in: range)
        if let token = token as? MentionToken, effectiveRange.location != NSNotFound {
            let middle = effectiveRange.location + 1 + token.length / 2
            isFloatingCursorGoingBackward = location < middle
            isFloatingCursorGoingForward = location >= middle
        } else {
            isFloatingCursorGoingBackward = false
            isFloatingCursorGoingForward = true
        }
    }
    
    override func endFloatingCursor() {
        super.endFloatingCursor()
        isFloatingCursor = false
    }
    
}
