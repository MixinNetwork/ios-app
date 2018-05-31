import UIKit

class TextMessageLabel: CoreTextLabel {

    static let gestureRecognizerBypassingDelegateObject = GestureRecognizerBypassingDelegateObject()

    var highlightPaths = [UIBezierPath]()
    
    private let highlightColor = UIColor.messageKeywordHighlight

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
    
    class GestureRecognizerBypassingDelegateObject: NSObject, UIGestureRecognizerDelegate {
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let label = touch.view as? TextMessageLabel else {
                return true
            }
            return !label.canResponseTouch(at: touch.location(in: label))
        }
        
    }

}
