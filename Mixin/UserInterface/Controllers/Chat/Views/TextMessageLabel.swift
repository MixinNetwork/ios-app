import UIKit

class TextMessageLabel: CoreTextLabel {

    var highlightPaths = [UIBezierPath]()
    
    private let highlightColor = R.color.chat_text_highlighted()!

    override func additionalDrawings() {
        highlightColor.setFill()
        for path in highlightPaths {
            path.fill()
        }
    }
    
    func canResponseTouch(at point: CGPoint) -> Bool {
        guard let content = content else {
            return false
        }
        for link in content.links {
            if link.hitFrame.applying(coreTextTransform).contains(point) {
                return true
            }
        }
        return false
    }
    
}
