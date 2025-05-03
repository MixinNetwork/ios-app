import UIKit

class RecognizeWindow: BottomSheetView {
    
    @IBOutlet weak var contentTextView: UITextView!
    @IBOutlet weak var copyButton: UIButton!
    @IBOutlet weak var actionButton: RoundedButton!
    @IBOutlet weak var actionButtonBottomConstraint: NSLayoutConstraint!
    
    private var validURL: URL?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentTextView.delegate = self
    }
    
    func presentWindow(text: String) {
        contentTextView.text = text
        if textIsValidURL, let url = URL(string: text) {
            validURL = url
            actionButton.setTitle(R.string.localizable.open(), for: .normal)
            actionButtonBottomConstraint.constant = -12
            actionButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 38, bottom: 12, right: 38)
            copyButton.isHidden = false
        } else {
            actionButtonBottomConstraint.constant = copyButton.bounds.height
        }
        presentPopupControllerAnimated()
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        if let url = validURL {
            open(url)
        } else {
            copyContent()
        }
    }
    
    @IBAction func copyAction(_ sender: Any) {
        copyContent()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }
    
    class func instance() -> RecognizeWindow {
        return Bundle.main.loadNibNamed("RecognizeWindow", owner: nil, options: nil)?.first as! RecognizeWindow
    }
    
    private var textIsValidURL: Bool {
        guard let text = contentTextView.text,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let match = detector.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) else {
            return false
        }
        return match.range.length == text.utf16.count
    }
    
    private func copyContent() {
        UIPasteboard.general.string = contentTextView.text
        dismissPopupController(animated: true)
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
    @discardableResult private func open(_ url: URL) -> Bool {
        guard let container = UIApplication.homeContainerViewController else {
            return true
        }
        dismissPopupController(animated: true)
        container.presentWebViewController(context: .init(conversationId: "", initialUrl: url))
        return false
    }
    
}

extension RecognizeWindow: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return open(URL)
    }
    
}
