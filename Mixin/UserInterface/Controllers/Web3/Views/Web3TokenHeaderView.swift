import UIKit
import MixinServices

final class Web3TokenHeaderView: UIView {
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountTextView: UITextView!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    @IBOutlet weak var actionStackView: UIStackView!
    
    private weak var sendButton: UIButton!
    private weak var receiveButton: UIButton!
    
    private var token: Web3Token?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        amountTextView.textContainerInset = .zero
        sendButton = addAction(title: R.string.localizable.caption_send(),
                               icon: R.image.web3_action_send()!)
        receiveButton = addAction(title: R.string.localizable.receive(),
                                  icon: R.image.web3_action_receive()!)
        actionStackView.addArrangedSubview(UIView())
        actionStackView.addArrangedSubview(UIView())
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection), let token {
            render(token: token)
        }
    }
    
    func render(token: Web3Token) {
        assetIconView.setIcon(web3Token: token)
        
        let amount = CurrencyFormatter.localizedString(from: token.balance, format: .precision, sign: .never) ?? ""
        let attributedAmount = attributedString(amount: amount, symbol: token.symbol)
        amountTextView.attributedText = attributedAmount
        fiatMoneyValueLabel.text = token.localizedFiatMoneyBalance
        
        let range = NSRange(location: 0, length: attributedAmount.length)
        var lineCount = 0
        var lastLineGlyphCount = 0
        amountTextView.layoutManager.enumerateLineFragments(forGlyphRange: range) { (rect, usedRect, textContainer, glyphRange, stop) in
            lastLineGlyphCount = glyphRange.length
            lineCount += 1
        }
        let minGlyphCountOfLastLine = 4 // 3 digits and 1 asset symbol
        if lineCount > 1 && lastLineGlyphCount < minGlyphCountOfLastLine {
            let linebreak = NSAttributedString(string: "\n")
            attributedAmount.insert(linebreak, at: attributedAmount.length - minGlyphCountOfLastLine)
            amountTextView.attributedText = attributedAmount
        }
        self.token = token
    }
    
    func addTarget(_ target: Any, send: Selector, receive: Selector) {
        sendButton.removeTarget(nil, action: nil, for: .allEvents)
        sendButton.addTarget(target, action: send, for: .touchUpInside)
        
        receiveButton.removeTarget(nil, action: nil, for: .allEvents)
        receiveButton.addTarget(target, action: receive, for: .touchUpInside)
    }
    
    private func attributedString(amount: String, symbol: String) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFontMetrics.default.scaledFont(for: .condensed(size: 34)),
            .foregroundColor: UIColor.text
        ]
        let str = NSMutableAttributedString(string: amount, attributes: attrs)
        let attachment = SymbolTextAttachment(text: symbol)
        str.append(NSAttributedString(attachment: attachment))
        return str
    }
    
    private func addAction(title: String, icon: UIImage) -> UIButton {
        let wrapper = UIView()
        
        let backgroundImageView = UIImageView(image: R.image.explore.action_tray())
        wrapper.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        
        let label = UILabel()
        label.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
        label.textColor = R.color.text()
        label.textAlignment = .center
        label.text = title
        wrapper.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        let button = UIButton(type: .system)
        button.contentMode = .center
        button.tintColor = R.color.icon_tint()
        button.setImage(icon, for: .normal)
        wrapper.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalTo(backgroundImageView)
        }
        
        actionStackView.addArrangedSubview(wrapper)
        return button
    }
}
