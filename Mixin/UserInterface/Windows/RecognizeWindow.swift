import UIKit

final class RecognizeWindow: UIViewController {
    
    @IBOutlet weak var contentTextView: UITextView!
    @IBOutlet weak var copyButton: UIButton!
    @IBOutlet weak var actionButton: RoundedButton!
    @IBOutlet weak var actionButtonBottomConstraint: NSLayoutConstraint!
    
    private let text: String
    private var validURL: URL?
    
    init(text: String) {
        self.text = text
        let nib = R.nib.recognizeWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentTextView.delegate = self
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
        dismiss(animated: true)
    }
    
    private var textIsValidURL: Bool {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let match = detector?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return match?.range.length == text.utf16.count
    }
    
    private func copyContent() {
        UIPasteboard.general.string = contentTextView.text
        dismiss(animated: true) {
            showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        }
    }
    
    @discardableResult private func open(_ url: URL) -> Bool {
        guard let navigationController = UIApplication.shared.homeNavigationController else {
            return true
        }
        dismiss(animated: true) {
            navigationController.pushWebViewController(
                context: .init(conversationID: "", initialURL: url)
            )
        }
        return false
    }
    
}

extension RecognizeWindow: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return open(URL)
    }
    
}
