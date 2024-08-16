import UIKit
import MixinServices

final class TokenBalanceCell: UITableViewCell {
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountTextView: UITextView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var actionView: TransferActionView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleStackView.setCustomSpacing(10, after: titleLabel)
        amountTextView.textContainerInset = .zero
        amountTextView.textContainer.lineFragmentPadding = 0
        actionView.actions = [.send, .receive, .swap]
    }
    
    func reloadData(token: TokenItem) {
        iconView.setIcon(token: token)
        var amount: String
        if token.decimalBalance == 0 {
            amount = zeroWith2Fractions
            valueLabel.text = "≈ " + Currency.current.symbol + zeroWith2Fractions
        } else {
            amount = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            valueLabel.text = token.localizedFiatMoneyBalance
        }
        if amount.count > 3 {
            var index = amount.index(amount.endIndex, offsetBy: -3)
            let beforeIndex = amount.index(before: index)
            let afterIndex = amount.index(after: index)
            if amount[index..<afterIndex] == currentDecimalSeparator {
                // Avoid decimal separator being first character of the new line
                if beforeIndex == amount.startIndex {
                    index = afterIndex
                } else {
                    index = beforeIndex
                }
            }
            amount.insert("\u{200B}", at: index)
        }
        let amountAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFontMetrics.default.scaledFont(for: .condensed(size: 34)),
            .foregroundColor: R.color.text()!,
        ]
        let attributedAmount = NSMutableAttributedString(string: amount, attributes: amountAttributes)
        
        let symbolAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: R.color.text()!,
        ]
        let attributedSymbol = NSAttributedString(string: "\u{2060} \u{2060}\(token.symbol)", attributes: symbolAttributes)
        
        attributedAmount.append(attributedSymbol)
        amountTextView.attributedText = attributedAmount
    }
    
}
