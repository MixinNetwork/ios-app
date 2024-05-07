import UIKit

class SymbolTextAttachment: NSTextAttachment {
    
    let leadingMargin: CGFloat = 6
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(text: String) {
        super.init(data: nil, ofType: nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.text
        ]
        let str = NSAttributedString(string: text, attributes: attributes)
        let textSize = str.size()
        let canvasSize = CGSize(width: leadingMargin + textSize.width, height: textSize.height)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, UIScreen.main.scale)
        str.draw(at: CGPoint(x: leadingMargin, y: 0))
        self.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        var bounds = super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: position, characterIndex: charIndex)
        bounds.origin.y = -2
        return bounds
    }
    
}
