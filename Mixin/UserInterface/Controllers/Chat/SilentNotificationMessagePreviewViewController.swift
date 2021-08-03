import UIKit

protocol SilentNotificationMessagePreviewViewControllerDelegate: AnyObject {
    func silentNotificationMessagePreviewViewControllerWillShow(_ viewController: SilentNotificationMessagePreviewViewController)
    func silentNotificationMessagePreviewViewController(_ viewController: SilentNotificationMessagePreviewViewController, didSelectSendWithNotification notify: Bool)
    func silentNotificationMessagePreviewViewControllerDidClose(_ viewController: SilentNotificationMessagePreviewViewController)
}

class SilentNotificationMessagePreviewViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var messageBackgroundView: UIImageView!
    @IBOutlet weak var textView: ConversationInputTextView!
    @IBOutlet weak var normalButton: UIButton!
    @IBOutlet weak var silentButton: HighlightableButton!
    
    weak var delegate: SilentNotificationMessagePreviewViewControllerDelegate?
    
    private let feedback = UIImpactFeedbackGenerator()
    private let silentButtonTopMargin: CGFloat = 20
    private let silentButtonTrailingMargin: CGFloat = 3
    private let textViewHorizontalOffset: CGFloat = 8
    private let messageBackgroundInsets = UIEdgeInsets(top: 2, left: 11, bottom: 0, right: 2)
    
    private var normalButtonOriginalFrame: CGRect?
    private var textViewOriginalFrame: CGRect?
    private var textViewOriginalContentOffset: CGPoint?
    
    private var sendSilentlyHiddenTransform: CGAffineTransform {
        let scale = normalButton.frame.width / silentButton.frame.width
        let translation = normalButton.center - silentButton.center
        return CGAffineTransform(translationX: translation.x, y: translation.y)
            .scaledBy(x: scale, y: scale)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundView.effect = nil
    }
    
    @IBAction func sendNormally(_ sender: Any) {
        delegate?.silentNotificationMessagePreviewViewController(self, didSelectSendWithNotification: true)
    }
    
    @IBAction func sendSilently(_ sender: Any) {
        delegate?.silentNotificationMessagePreviewViewController(self, didSelectSendWithNotification: false)
    }
    
    @IBAction func close(_ sender: Any) {
        dismiss(hideSendNormallyButton: false)
    }
    
    func show(
        in parent: UIViewController,
        layout: (_ contentView: UIView, _ textView: UITextView, _ sendButton: UIButton) -> Void
    ) {
        delegate?.silentNotificationMessagePreviewViewControllerWillShow(self)
        feedback.impactOccurred()
        
        view.frame = parent.view.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addChild(self)
        parent.view.addSubview(view)
        didMove(toParent: parent)
        
        normalButton.alpha = 1
        silentButton.alpha = 0
        silentButton.sizeToFit()
        
        layout(contentView, textView, normalButton)
        textViewOriginalFrame = textView.frame
        textViewOriginalContentOffset = textView.contentOffset
        normalButtonOriginalFrame = normalButton.frame
        messageBackgroundView.frame = textView.frame.inset(by: messageBackgroundInsets)
        
        var silentButtonOrigin = CGPoint(x: textView.frame.maxX - silentButtonTrailingMargin - silentButton.bounds.width,
                                         y: textView.frame.maxY + silentButtonTopMargin)
        let verticalOffset = (silentButtonOrigin.y + silentButton.bounds.height) - (view.bounds.height - view.safeAreaInsets.bottom)
        if verticalOffset > 0 {
            silentButtonOrigin.y -= verticalOffset
        }
        silentButton.frame.origin = silentButtonOrigin
        silentButton.transform = sendSilentlyHiddenTransform
        
        let trailingEmptyWidth = textView.frame.size.width
            - textView.textContainerInset.horizontal
            - textView.textContainer.lineFragmentPadding * 2
            - textWidth(within: textView)
        UIView.animate(withDuration: 0.25) {
            self.view.backgroundColor = .black.withAlphaComponent(0.24)
            self.backgroundView.effect = .regularBlur
            self.silentButton.transform = .identity
            self.silentButton.alpha = 1
            
            self.textView.frame.origin.x += self.textViewHorizontalOffset
            if trailingEmptyWidth > 0 {
                self.textView.frame.size.width -= trailingEmptyWidth
                self.textView.frame.origin.x += trailingEmptyWidth
            }
            let topExpanding = self.textView.contentOffset.y
            if topExpanding > 0 {
                self.textView.frame.size.height += topExpanding
                self.textView.frame.origin.y -= topExpanding
                self.textView.contentOffset.y = 0
            }
            let bottomExpanding = self.textView.contentSize.height - self.textView.frame.size.height
            if bottomExpanding > 0 {
                self.textView.frame.size.height += bottomExpanding
                self.textView.frame.origin.y -= bottomExpanding
                self.textView.contentOffset.y = self.textView.contentSize.height - self.textView.frame.size.height
            }
            if verticalOffset > 0 {
                self.textView.frame.origin.y -= verticalOffset
            }
            
            self.messageBackgroundView.alpha = 1
            self.messageBackgroundView.frame = self.textView.frame.inset(by: self.messageBackgroundInsets)
        }
    }
    
    func handleGestureChange(with recognizer: UIGestureRecognizer) {
        let location = recognizer.location(in: silentButton)
        let isGestureLocatedInSendSilently = silentButton.bounds.contains(location)
        switch recognizer.state {
        case .changed:
            silentButton.isHighlighted = isGestureLocatedInSendSilently
        case .ended:
            if isGestureLocatedInSendSilently {
                sendSilently(recognizer)
            }
        default:
            break
        }
    }
    
    func dismiss(hideSendNormallyButton: Bool) {
        if hideSendNormallyButton {
            normalButton.alpha = 0
        }
        UIView.animate(withDuration: 0.25) {
            self.view.backgroundColor = .black.withAlphaComponent(0)
            self.backgroundView.effect = nil
            self.messageBackgroundView.alpha = 0
            if let frame = self.textViewOriginalFrame {
                self.textView.frame = frame
                self.messageBackgroundView.frame = frame.inset(by: self.messageBackgroundInsets)
            }
            if let offset = self.textViewOriginalContentOffset {
                self.textView.contentOffset = offset
            }
            if let frame = self.normalButtonOriginalFrame {
                self.normalButton.frame = frame
            }
            self.silentButton.transform = self.sendSilentlyHiddenTransform
            self.silentButton.alpha = 0
        } completion: { _ in
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            self.delegate?.silentNotificationMessagePreviewViewControllerDidClose(self)
        }
    }
    
    private func textWidth(within textView: UITextView) -> CGFloat {
        guard let text = textView.text, !text.isEmpty else {
            return .zero
        }
        
        let invalidRange = NSRange(location: NSNotFound, length: 0)
        let range = NSRange(location: 0, length: (text as NSString).length)
        
        var glyphRange = invalidRange
        textView.layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        guard glyphRange != invalidRange else {
            return .zero
        }
        
        let rect = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
        return rect.width
    }
    
}
