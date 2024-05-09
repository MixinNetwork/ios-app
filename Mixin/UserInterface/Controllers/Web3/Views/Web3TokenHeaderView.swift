import UIKit
import MixinServices

final class Web3TokenHeaderView: Web3HeaderView {
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountTextView: UITextView!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    private var token: Web3Token?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        amountTextView.textContainerInset = .zero
        amountTextView.textContainer.lineFragmentPadding = 0
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
    
}
