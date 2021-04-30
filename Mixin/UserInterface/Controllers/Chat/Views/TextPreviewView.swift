import UIKit

protocol TextPreviewViewDelegate: AnyObject {
    func textPreviewView(_ view: TextPreviewView, didSelectURL url: URL)
    func textPreviewView(_ view: TextPreviewView, didLongPressURL url: URL)
    func textPreviewViewDidFinishPreview(_ view: TextPreviewView)
}

class TextPreviewView: UIView {
    
    @IBOutlet weak var visualEffectView: UIVisualEffectView!
    @IBOutlet weak var textView: LinkLocatingTextView!
    @IBOutlet weak var tapRecognizer: UITapGestureRecognizer!
    
    weak var delegate: TextPreviewViewDelegate?
    
    var attributedText: NSAttributedString? {
        get {
            textView.attributedText
        }
        set {
            let text = NSMutableAttributedString(attributedString: newValue ?? NSAttributedString())
            let range = NSRange(location: 0, length: text.length)
            text.addAttributes(attributes, range: range)
            textView.attributedText = text
            layoutText()
        }
    }
    
    private var horizontalMargin: CGFloat {
        switch ScreenWidth.current {
        case .short:
            return 20
        default:
            return 36
        }
    }
    
    private var attributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 9
        return [.font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 24)),
                .paragraphStyle: paragraphStyle]
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.textDragInteraction?.isEnabled = false
        let bottomInset: CGFloat = AppDelegate.current.mainWindow.safeAreaInsets.bottom > 20 ? 0 : 20
        textView.contentInset = UIEdgeInsets(top: 0, left: horizontalMargin, bottom: bottomInset, right: horizontalMargin)
        tapRecognizer.delegate = self
        textView.delegate = self
    }
    
    @IBAction func finishPreview(_ sender: Any) {
        delegate?.textPreviewViewDidFinishPreview(self)
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
        if gestureRecognizer == tapRecognizer {
            if otherGestureRecognizer is UILongPressGestureRecognizer {
                return false
            } else if textView.hasLinkAttribute(on: tapRecognizer.location(in: textView)) {
                return false
            } else {
                return true
            }
        } else {
            return false
        }
    }
    
}

extension TextPreviewView: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        switch interaction {
        case .invokeDefaultAction:
            delegate?.textPreviewView(self, didSelectURL: URL)
        case .presentActions, .preview:
            delegate?.textPreviewView(self, didLongPressURL: URL)
        @unknown default:
            break
        }
        return false
    }
    
}
