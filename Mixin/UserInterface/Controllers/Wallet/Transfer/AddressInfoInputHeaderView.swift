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
    @IBOutlet weak var contentTopConstraint: NSLayoutConstraint!
    
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
    
    func load(token: any OnChainToken & ValuableToken) {
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
        tokenIconView.setIcon(token: token)
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
    
    func loadNetwork(name: String, isSwitchable: Bool, target: Any, action: Selector) {
        titleStackView.isHidden = true
        
        let captionLabel = UILabel()
        captionLabel.textColor = R.color.text_tertiary()
        captionLabel.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
        captionLabel.text = R.string.localizable.network()
        
        let nameLabel = UILabel()
        nameLabel.textColor = R.color.text()
        nameLabel.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        nameLabel.text = name
        
        let labelStackView = UIStackView(arrangedSubviews: [captionLabel, nameLabel])
        labelStackView.axis = .vertical
        labelStackView.spacing = 6
        
        let networkView = UIView()
        networkView.backgroundColor = R.color.background()
        networkView.layer.cornerRadius = 8
        networkView.layer.masksToBounds = true
        networkView.addSubview(labelStackView)
        labelStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-14)
        }
        if isSwitchable {
            let arrowView = UIImageView(image: R.image.arrow_down_compact())
            arrowView.tintColor = R.color.icon_tint_tertiary()
            arrowView.contentMode = .center
            networkView.addSubview(arrowView)
            arrowView.snp.makeConstraints { make in
                make.leading.equalTo(labelStackView.snp.trailing).offset(16)
                make.trailing.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
            }
            arrowView.setContentHuggingPriority(.required, for: .horizontal)
            let button = UIButton(type: .custom)
            button.addTarget(target, action: action, for: .touchUpInside)
            networkView.addSubview(button)
            button.snp.makeEdgesEqualToSuperview()
        } else {
            labelStackView.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-16)
            }
        }
        contentStackView.insertArrangedSubview(networkView, at: 0)
    }
    
    func addInfoView(title: String, content: String, iconURL: String?) {
        titleStackView.isHidden = true
        
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.text_tertiary()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        titleLabel.text = title
        
        let contentLabel = UILabel()
        contentLabel.textColor = R.color.text_secondary()
        contentLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        contentLabel.numberOfLines = 0
        contentLabel.textAlignment = .right
        contentLabel.lineBreakMode = .byCharWrapping
        contentLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentLabel.text = content
        
        let contentStackView = UIStackView(arrangedSubviews: [contentLabel])
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = 4
        if let iconURL {
            let iconView = PlainTokenIconView(frame: .zero)
            iconView.setIcon(urlString: iconURL)
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(20)
            }
            contentStackView.insertArrangedSubview(iconView, at: 0)
        } else {
            contentLabel.snp.makeConstraints { make in
                make.width.lessThanOrEqualTo(200)
            }
        }
        
        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
        spacerView.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(16)
        }
        let stackView = UIStackView(arrangedSubviews: [titleLabel, spacerView, contentStackView])
        stackView.axis = .horizontal
        stackView.alignment = iconURL == nil ? .top : .center
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        self.contentStackView.addArrangedSubview(stackView)
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
