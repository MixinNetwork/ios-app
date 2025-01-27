import UIKit
import MixinServices

final class AddressInfoInputCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func addressInfoInputCell(_ cell: AddressInfoInputCell, didUpdateContent content: String?)
        func addressInfoInputCellWantsToScanContent(_ cell: AddressInfoInputCell)
    }
    
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
    
    private var content: String? {
        if let text = textView.text, !text.isEmpty {
            text
        } else {
            nil
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tokenChainLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        tokenChainLabel.layer.cornerRadius = 4
        tokenChainLabel.layer.masksToBounds = true
        textViewBackgroundView.layer.cornerRadius = 8
        textViewBackgroundView.layer.masksToBounds = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewDidChange(_:)),
            name: UITextView.textDidChangeNotification,
            object: textView
        )
        updateActionButton()
    }
    
    func load(token: TokenItem) {
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
    
    @objc private func textViewDidChange(_ notification: Notification) {
        let content = self.content
        placeholderLabel.isHidden = content != nil
        delegate?.addressInfoInputCell(self, didUpdateContent: content)
    }
    
    @objc private func clearInput(_ sender: Any) {
        textView.text = ""
        updateActionButton()
    }
    
    @objc private func scanQRCode(_ sender: Any) {
        delegate?.addressInfoInputCellWantsToScanContent(self)
    }
    
    private func updateActionButton() {
        if content == nil {
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
