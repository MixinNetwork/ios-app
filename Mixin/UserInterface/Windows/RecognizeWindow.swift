import UIKit

class RecognizeWindow: BottomSheetView {

    @IBOutlet weak var contentTextView: UITextView!
    
    @IBOutlet weak var hidePopupViewConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentTextView.delegate = self
    }

    func presentWindow(text: String) {
        contentTextView.text = text
        presentPopupControllerAnimated()
    }

    @IBAction func copyAction(_ sender: Any) {
        UIPasteboard.general.string = contentTextView.text
        dismissPopupControllerAnimated()
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
    override func presentPopupControllerAnimated() {
        UIApplication.currentActivity()?.view.endEditing(true)
        guard !isShowing, let window = UIApplication.shared.keyWindow else {
            return
        }
        isShowing = true
        frame = window.bounds
        backgroundColor = windowBackgroundColor
        alpha = 0
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissPopupControllerAnimated))
        gestureRecognizer.delegate = self
        addGestureRecognizer(gestureRecognizer)
        
        window.addSubview(self)
        
        hidePopupViewConstraint.priority = .almostInexist
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.alpha = 1
            self.layoutIfNeeded()
        })
    }
    
    override func dismissPopupControllerAnimated() {
        alpha = 1
        isShowing = false
        hidePopupViewConstraint.priority = .almostRequired
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.alpha = 0
            self.layoutIfNeeded()
        }, completion: { (finished: Bool) -> Void in
            self.removeFromSuperview()
        })
    }
    
    class func instance() -> RecognizeWindow {
        return Bundle.main.loadNibNamed("RecognizeWindow", owner: nil, options: nil)?.first as! RecognizeWindow
    }
}

extension RecognizeWindow: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        guard let parent = UIApplication.homeNavigationController?.visibleViewController else {
            return true
        }
        dismissPopupControllerAnimated()
        WebViewController.presentInstance(with: .init(conversationId: "", initialUrl: URL), asChildOf: parent)
        return false
    }
    
}
