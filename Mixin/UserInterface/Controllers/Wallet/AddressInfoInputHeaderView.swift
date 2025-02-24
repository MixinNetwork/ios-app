import UIKit
import MixinServices

final class AddressInfoInputHeaderView: UIView {
    
    protocol Delegate: AnyObject {
        func addressInfoInputHeaderView(_ headerView: AddressInfoInputHeaderView, didUpdateContent content: String)
        func addressInfoInputHeaderViewWantsToScanContent(_ headerView: AddressInfoInputHeaderView)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var tokenIconView: PlainTokenIconView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var tokenChainLabel: InsetLabel!
    @IBOutlet weak var tokenBalanceLabel: UILabel!
    @IBOutlet weak var textViewBackgroundView: UIView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var placeholderLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    weak var delegate: Delegate?
    
    var inputPlaceholder: String? {
        didSet {
            placeholderLabel.text = inputPlaceholder
        }
    }
    
    var trimmedContent: String {
        textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tokenChainLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        tokenChainLabel.layer.cornerRadius = 4
        tokenChainLabel.layer.masksToBounds = true
        textViewBackgroundView.layer.cornerRadius = 8
        textViewBackgroundView.layer.masksToBounds = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewDidChange(_:)),
            name: UITextView.textDidChangeNotification,
            object: textView
        )
        updateActionButton()
    }
    
    func load(token: MixinTokenItem) {
        tokenIconView.setIcon(token: token)
        tokenNameLabel.text = token.name
        if let tag = token.chainTag {
            tokenChainLabel.text = tag
            tokenChainLabel.isHidden = false
        } else {
            tokenChainLabel.isHidden = true
        }
        tokenBalanceLabel.text = R.string.localizable.balance_abbreviation(token.localizedBalanceWithSymbol)
    }
    
    func load(web3Token token: Web3Token) {
        tokenIconView.setIcon(web3Token: token)
        tokenNameLabel.text = token.name
        tokenChainLabel.isHidden = true
        tokenBalanceLabel.text = R.string.localizable.balance_abbreviation(token.localizedBalanceWithSymbol)
    }
    
    func setContent(_ content: String) {
        textView.text = content
        placeholderLabel.isHidden = !content.isEmpty
        updateActionButton()
        delegate?.addressInfoInputHeaderView(self, didUpdateContent: trimmedContent)
    }
    
    func addAddressView(configure: (UILabel) -> Void) {
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.text_tertiary()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        titleLabel.text = R.string.localizable.address()
        
        let contentLabel = UILabel()
        contentLabel.textColor = R.color.text_tertiary()
        contentLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        contentLabel.numberOfLines = 0
        contentLabel.textAlignment = .right
        contentLabel.lineBreakMode = .byCharWrapping
        contentLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configure(contentLabel)
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, contentLabel])
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 16
        contentStackView.addArrangedSubview(stackView)
    }
    
    @objc private func textViewDidChange(_ notification: Notification) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateActionButton()
        delegate?.addressInfoInputHeaderView(self, didUpdateContent: trimmedContent)
    }
    
    @objc private func clearInput(_ sender: Any) {
        setContent("")
    }
    
    @objc private func scanQRCode(_ sender: Any) {
        delegate?.addressInfoInputHeaderViewWantsToScanContent(self)
    }
    
    private func updateActionButton() {
        if textView.text.isEmpty {
            actionButton.setImage(R.image.explore.web3_send_scan(), for: .normal)
            actionButton.removeTarget(self, action: nil, for: .touchUpInside)
            actionButton.addTarget(self, action: #selector(scanQRCode(_:)), for: .touchUpInside)
        } else {
            actionButton.setImage(R.image.explore.web3_send_delete(), for: .normal)
            actionButton.removeTarget(self, action: nil, for: .touchUpInside)
            actionButton.addTarget(self, action: #selector(clearInput(_:)), for: .touchUpInside)
        }
    }
    
}
