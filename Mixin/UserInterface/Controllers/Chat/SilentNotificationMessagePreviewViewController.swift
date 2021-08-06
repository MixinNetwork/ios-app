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
    @IBOutlet weak var textViewWrapperView: UIView!
    @IBOutlet weak var textView: ConversationInputTextView!
    @IBOutlet weak var normalButton: UIButton!
    @IBOutlet weak var silentButton: HighlightableButton!
    
    weak var delegate: SilentNotificationMessagePreviewViewControllerDelegate?
    
    private let feedback = UIImpactFeedbackGenerator()
    private let silentButtonTopMargin: CGFloat = 20
    private let silentButtonTrailingMargin: CGFloat = 3
    private let textViewHorizontalOffset: CGFloat = 8
    private let messageBackgroundInsets = UIEdgeInsets(top: 2, left: 11, bottom: 0, right: 2)
    
    private var initialNormalButtonFrame: CGRect?
    private var initialTextViewWrapperFrame: CGRect?
    private var initialTextViewContentOffset: CGPoint?
    
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
    
    func show(in parent: UIViewController, textView templateTextView: UITextView, sendButton templateSendButton: UIButton) {
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
        
        if let superview = templateTextView.superview {
            textViewWrapperView.frame = superview.convert(templateTextView.frame, to: contentView)
            initialTextViewWrapperFrame = textViewWrapperView.frame
            textView.frame = textViewWrapperView.bounds
        }
        textView.textContainerInset = templateTextView.textContainerInset
        textView.text = templateTextView.text
        textView.contentOffset = templateTextView.contentOffset
        initialTextViewContentOffset = templateTextView.contentOffset
        if let superview = templateSendButton.superview {
            normalButton.frame = superview.convert(templateSendButton.frame, to: contentView)
            initialNormalButtonFrame = normalButton.frame
        }
        
        messageBackgroundView.frame = textViewWrapperView.frame.inset(by: messageBackgroundInsets)
        
        var silentButtonOrigin = CGPoint(x: textViewWrapperView.frame.maxX - silentButtonTrailingMargin - silentButton.bounds.width,
                                         y: textViewWrapperView.frame.maxY + silentButtonTopMargin)
        let verticalOffset: CGFloat = {
            let offset = (silentButtonOrigin.y + silentButton.bounds.height)
                - (view.bounds.height - view.safeAreaInsets.bottom)
            return max(0, offset)
        }()
        if verticalOffset > 0 {
            silentButtonOrigin.y -= verticalOffset
        }
        silentButton.frame.origin = silentButtonOrigin
        silentButton.transform = sendSilentlyHiddenTransform
        
        let trailingEmptyWidth: CGFloat = {
            let width = textView.frame.size.width
                - textView.textContainerInset.horizontal
                - textView.textContainer.lineFragmentPadding * 2
                - textWidth(within: textView)
            return max(0, width)
        }()
        let topExpanding = max(0, textView.contentOffset.y)
        let bottomExpanding: CGFloat = {
            let height = textView.contentSize.height
                - textView.contentOffset.y
                - textView.frame.size.height
            return max(0, height)
        }()
        let textWrapperFrame = CGRect(x: textViewWrapperView.frame.origin.x + textViewHorizontalOffset + trailingEmptyWidth,
                                      y: textViewWrapperView.frame.origin.y - topExpanding - bottomExpanding - verticalOffset,
                                      width: textViewWrapperView.frame.width - trailingEmptyWidth,
                                      height: textViewWrapperView.frame.height + topExpanding + bottomExpanding)
        textView.frame = CGRect(x: textView.frame.origin.x,
                                y: textView.frame.origin.y - textView.contentOffset.y,
                                width: textWrapperFrame.width,
                                height: textWrapperFrame.height)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.backgroundColor = .black.withAlphaComponent(0.24)
            self.backgroundView.effect = .regularBlur
            self.textViewWrapperView.frame = textWrapperFrame
            self.textView.frame = self.textViewWrapperView.bounds
            self.messageBackgroundView.frame = self.textViewWrapperView.frame.inset(by: self.messageBackgroundInsets)
            self.silentButton.transform = .identity
            self.silentButton.alpha = 1
        }
        UIView.animate(withDuration: 0.2) {
            self.messageBackgroundView.alpha = 1
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
        UIView.animate(withDuration: 0.4) {
            self.messageBackgroundView.alpha = 0
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.backgroundColor = .black.withAlphaComponent(0)
            self.backgroundView.effect = nil
            if let frame = self.initialTextViewWrapperFrame {
                self.textViewWrapperView.frame = frame
                self.messageBackgroundView.frame = frame.inset(by: self.messageBackgroundInsets)
            }
            if let offset = self.initialTextViewContentOffset {
                self.textView.contentOffset = offset
            }
            self.textView.frame = self.textViewWrapperView.bounds
            if let frame = self.initialNormalButtonFrame {
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
