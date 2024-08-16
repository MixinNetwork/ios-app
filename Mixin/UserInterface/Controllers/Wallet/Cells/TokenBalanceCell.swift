import UIKit
import MixinServices

final class TokenBalanceCell: UITableViewCell {
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountTextView: UITextView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var actionView: TransferActionView!
    
    var token: TokenItem? {
        didSet {
            guard let token, token !== oldValue else {
                return
            }
            reloadData(token: token)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleStackView.setCustomSpacing(10, after: titleLabel)
        amountTextView.textContainerInset = .zero
        amountTextView.textContainer.lineFragmentPadding = 0
        actionView.actions = [.send, .receive, .swap]
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection), let token {
            reloadData(token: token)
        }
    }
    
    private func reloadData(token: TokenItem) {
        iconView.setIcon(token: token)
        let amount: String
        if token.decimalBalance == 0 {
            amount = zeroWith2Fractions
            valueLabel.text = "≈ " + Currency.current.symbol + zeroWith2Fractions
        } else {
            amount = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            valueLabel.text = token.localizedFiatMoneyBalance
        }
        let attributedAmount = attributedString(amount: amount, symbol: token.symbol)
        amountTextView.attributedText = attributedAmount
        
        // TODO: Uncomment these lines for linebreaking on specific length of amount
        // Currently this corrupts cell layout because when the cell is set with `token`,
        // `cell.bounds` will change multiple times after, which cause character finding
        // results in wrong.
        
//        let range = NSRange(location: 0, length: attributedAmount.length)
//        var lineCount = 0
//        var lastLineGlyphCount = 0
//        amountTextView.layoutManager.enumerateLineFragments(forGlyphRange: range) { (rect, usedRect, textContainer, glyphRange, stop) in
//            lastLineGlyphCount = glyphRange.length
//            lineCount += 1
//        }
//        let minGlyphCountOfLastLine = 4 // 3 digits and 1 asset symbol
//        if lineCount > 1 && lastLineGlyphCount < minGlyphCountOfLastLine {
//            let linebreak = NSAttributedString(string: "\n")
//            attributedAmount.insert(linebreak, at: attributedAmount.length - minGlyphCountOfLastLine)
//            amountTextView.attributedText = attributedAmount
//        }
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
