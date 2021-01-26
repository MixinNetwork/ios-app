import UIKit

class LinkLocatingTextView: UITextView {
    
    func hasLinkAttribute(on point: CGPoint) -> Bool {
        guard layoutManager.usedRect(for: textContainer).contains(point) else {
            return false
        }
        guard let position = closestPosition(to: point) else {
            return false
        }
        guard let range = tokenizer.rangeEnclosingPosition(position, with: .character, inDirection: .layout(.left)) else {
            return false
        }
        let startIndex = offset(from: beginningOfDocument, to: range.start)
        return attributedText.attribute(.link, at: startIndex, effectiveRange: nil) != nil
    }
    
}
