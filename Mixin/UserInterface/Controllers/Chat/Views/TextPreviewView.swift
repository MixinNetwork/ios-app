import UIKit

class TextPreviewView: UIView {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var tapRecognizer: UITapGestureRecognizer!
    
    private let horizontalMargin: CGFloat = 20
    
    var text: String? {
        get {
            textView.text
        }
        set {
            textView.text = newValue ?? ""
            layoutText()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.contentInset = UIEdgeInsets(top: 0, left: horizontalMargin, bottom: 0, right: horizontalMargin)
        tapRecognizer.delegate = self
    }
    
    private func layoutText() {
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        let textRect = textView.layoutManager.usedRect(for: textView.textContainer)
        let emptySpace = textView.bounds.size.height - ceil(textRect.height)
        let topInset = floor(max(0, emptySpace / 2.3)) // Place text a little bit above the center line for better view
        textView.contentInset.top = topInset
        if let font = textView.font {
            let numberOfLines = Int(textRect.height / font.lineHeight)
            textView.textAlignment = numberOfLines == 1 ? .center : .natural
        }
    }
    
}

extension TextPreviewView: UIGestureRecognizerDelegate {
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == tapRecognizer {
            return textView.selectedRange.length == 0
                && !textView.isDragging
                && !textView.isDecelerating
        } else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return !(otherGestureRecognizer is UILongPressGestureRecognizer)
    }
    
}
