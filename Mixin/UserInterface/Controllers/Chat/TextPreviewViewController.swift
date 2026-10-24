import UIKit
import MixinServices

protocol TextPreviewViewControllerDelegate: AnyObject {
    func textPreviewViewController(_ controller: TextPreviewViewController, didSelectURL url: URL)
    func textPreviewViewController(_ controller: TextPreviewViewController, didLongPressURL url: URL)
}

final class TextPreviewViewController: UIViewController {
    
    enum Text {
        case plain(String)
        case attributed(NSAttributedString)
    }
    
    @IBOutlet weak var textView: LinkLocatingTextView!
    @IBOutlet weak var tapRecognizer: UITapGestureRecognizer!
    
    weak var delegate: TextPreviewViewControllerDelegate?
    
    private let text: Text
    
    init(text: Text) {
        self.text = text
        let nib = R.nib.textPreviewView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch text {
        case .plain(let text):
            textView.text = text
        case .attributed(let text):
            let attributedText = NSMutableAttributedString(attributedString: text)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 9
            attributedText.addAttributes(
                [.font: UIFont.systemFont(ofSize: 24), .paragraphStyle: paragraphStyle],
                range: NSRange(location: 0, length: attributedText.length),
            )
            textView.attributedText = attributedText
        }
        textView.textDragInteraction?.isEnabled = false
        let horizontalMargin: CGFloat = switch ScreenWidth.current {
        case .short:
            20
        default:
            36
        }
        let bottomInset: CGFloat = view.safeAreaInsets.bottom > 20 ? 0 : 20
        textView.contentInset = UIEdgeInsets(
            top: 0,
            left: horizontalMargin,
            bottom: bottomInset,
            right: horizontalMargin,
        )
        tapRecognizer.delegate = self
        textView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(finishPreview(_:)),
            name: LoginManager.didLogoutNotification,
            object: nil,
        )
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        textView.contentInset.bottom = view.safeAreaInsets.bottom > 20 ? 0 : 20
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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
        // Place text a little above the center line for better viewing.
        textView.contentInset.top = floor(max(0, emptySpace / 2.5))
        
        let isMultilined: Bool
        if let font = textView.font {
            isMultilined = Int(textRect.height / font.lineHeight) > 1
        } else {
            isMultilined = true
        }
        textView.textAlignment = isMultilined ? .natural : .center
    }
    
    @IBAction func finishPreview(_ sender: Any) {
        guard !isBeingDismissed else {
            return
        }
        dismiss(animated: true)
    }
    
}

extension TextPreviewViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == tapRecognizer {
            return textView.selectedRange.length == 0
                && !textView.isDragging
                && !textView.isDecelerating
        } else {
            return true
        }
    }
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer,
    ) -> Bool {
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

extension TextPreviewViewController: UITextViewDelegate {
    
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction,
    ) -> Bool {
        switch interaction {
        case .invokeDefaultAction:
            delegate?.textPreviewViewController(self, didSelectURL: URL)
        case .presentActions, .preview:
            delegate?.textPreviewViewController(self, didLongPressURL: URL)
        @unknown default:
            break
        }
        return false
    }
    
}
