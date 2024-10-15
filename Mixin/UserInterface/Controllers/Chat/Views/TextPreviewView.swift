import UIKit
import MixinServices

protocol TextPreviewViewDelegate: AnyObject {
    func textPreviewView(_ view: TextPreviewView, didSelectURL url: URL)
    func textPreviewView(_ view: TextPreviewView, didLongPressURL url: URL)
}

final class TextPreviewView: UIView {
    
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
        return [.font: UIFont.systemFont(ofSize: 24),
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
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        let center = NotificationCenter.default
        if superview == nil {
            center.removeObserver(self)
        } else {
            center.addObserver(self,
                               selector: #selector(finishPreview(_:)),
                               name: LoginManager.didLogoutNotification,
                               object: nil)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let textRect: CGRect
        if #available(iOS 18.0, *),
           let manager = textView.textLayoutManager,
           let nsDocumentRange = manager.textContentManager?.documentRange
        {
            // No menu presents after text selected on iOS 18 with TextKit1
            // Certain single-lined text breaks out of bounds on iOS 17 with TextKit2
            manager.ensureLayout(for: nsDocumentRange)
            textRect = manager.usageBoundsForTextContainer
        } else {
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            textRect = textView.layoutManager.usedRect(for: textView.textContainer)
        }
        let emptySpace = textView.bounds.size.height - ceil(textRect.height)
        let topInset = floor(max(0, emptySpace / 2.5)) // Place text a little bit above the center line for better view
        textView.contentInset.top = topInset
        
        let isMultilined: Bool
        if let font = textView.font {
            isMultilined = Int(textRect.height / font.lineHeight) > 1
        } else {
            isMultilined = true
        }
        textView.textAlignment = isMultilined ? .natural : .center
    }
    
    func show(on superview: UIView) {
        alpha = 0
        superview.addSubview(self)
        snp.makeEdgesEqualToSuperview()
        setNeedsLayout()
        superview.layoutIfNeeded()
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
    
    @IBAction func finishPreview(_ sender: Any) {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        } completion: { (_) in
            self.removeFromSuperview()
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
