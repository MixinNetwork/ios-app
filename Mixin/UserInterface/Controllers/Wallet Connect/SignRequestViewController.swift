import UIKit

final class SignRequestViewController: WalletConnectRequestViewController {
    
    private let message: String
    private let messageTextView = UITextView()
    
    private lazy var successView = R.nib.sendSignatureSuccessView(owner: self)!
    
    private var messageTextViewHeightConstraint: NSLayoutConstraint!
    
    override var intentTitle: String {
        R.string.localizable.signature_request()
    }
    
    override var signingCompletionView: UIView {
        successView
    }
    
    init(requester: WalletConnectRequestViewController.Requester, message: String) {
        self.message = message
        super.init(requester: requester)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messageTextView.backgroundColor = .clear
        messageTextView.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        let scrollIndicatorInset = messageWrapperView.layer.cornerRadius
        messageTextView.scrollIndicatorInsets = UIEdgeInsets(top: scrollIndicatorInset, left: 0, bottom: scrollIndicatorInset, right: 0)
        messageTextView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        messageWrapperView.addSubview(messageTextView)
        messageTextView.snp.makeEdgesEqualToSuperview()
        messageTextViewHeightConstraint = messageTextView.heightAnchor
            .constraint(equalToConstant: messageTextView.contentSize.height)
        messageTextViewHeightConstraint.priority = .defaultLow
        messageTextViewHeightConstraint.isActive = true
        
        let attributedMessage = NSMutableAttributedString(string: "Message\n", attributes: [.font: UIFont.systemFont(ofSize: 14)])
        attributedMessage.append(NSAttributedString(string: " \n", attributes: [.font: UIFont.systemFont(ofSize: 8)]))
        attributedMessage.append(NSAttributedString(string: message, attributes: [.font: UIFont.systemFont(ofSize: 12)]))
        attributedMessage.setAttributes([.foregroundColor: UIColor.text], range: NSRange(location: 0, length: attributedMessage.length))
        messageTextView.attributedText = attributedMessage
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        messageTextViewHeightConstraint.constant = messageTextView.contentSize.height
    }
    
    override func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        if !isApproved {
            onReject?()
        }
    }
    
    @IBAction func done(_ sender: Any) {
        authenticationViewController?.presentingViewController?.dismiss(animated: true)
    }
    
}
