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
    
}
