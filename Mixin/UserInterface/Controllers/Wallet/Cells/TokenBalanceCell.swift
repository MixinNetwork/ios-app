import UIKit
import MixinServices

protocol TokenBalanceCellDelegate: AnyObject {
    func tokenBalanceCellWantsToRevealOutputs(_ cell: TokenBalanceCell)
}

final class TokenBalanceCell: UITableViewCell {
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var actionView: TokenActionView!
    
    @IBOutlet weak var showActionViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideActionViewConstraint: NSLayoutConstraint!
    
    weak var delegate: TokenBalanceCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleStackView.setCustomSpacing(10, after: titleLabel)
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(revealOutputs(_:)))
        recognizer.numberOfTapsRequired = 5
        iconView.addGestureRecognizer(recognizer)
        actionView.actions = [.receive, .send, .trade]
    }
    
    func reloadData(token: MixinTokenItem) {
        iconView.setIcon(token: token)
        var amount: String
        if token.decimalBalance == 0 {
            amount = zeroWith2Fractions
            valueLabel.text = "≈ " + Currency.current.symbol + zeroWith2Fractions
        } else {
            amount = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            valueLabel.text = token.estimatedFiatMoneyBalance
        }
        if amount.count > 3 {
            var index = amount.index(amount.endIndex, offsetBy: -3)
            let beforeIndex = amount.index(before: index)
            let afterIndex = amount.index(after: index)
            if !amount[index].isNumber {
                // Avoid decimal separator or grouping separator being first character of the new line
                if beforeIndex == amount.startIndex {
                    index = afterIndex
                } else {
                    index = beforeIndex
                }
            }
            amount.insert("\u{200B}", at: index)
        }
        let attributedAmount = NSMutableAttributedString(string: amount, attributes: [
            .font: UIFontMetrics.default.scaledFont(for: .condensed(size: 34)),
            .foregroundColor: R.color.text()!,
        ])
        let attributedSymbol = NSAttributedString(string: "\u{2060} \u{2060}\(token.symbol)", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: R.color.text()!,
        ])
        attributedAmount.append(attributedSymbol)
        amountLabel.attributedText = attributedAmount
    }
    
    func reloadData(web3Token token: Web3Token) {
        iconView.setIcon(web3Token: token)
        var amount: String
        if token.decimalBalance == 0 {
            amount = zeroWith2Fractions
            valueLabel.text = "≈ " + Currency.current.symbol + zeroWith2Fractions
        } else {
            amount = CurrencyFormatter.localizedString(
                from: token.decimalBalance,
                format: .precision,
                sign: .never
            )
            valueLabel.text = token.estimatedFiatMoneyBalance
        }
        if amount.count > 3 {
            var index = amount.index(amount.endIndex, offsetBy: -3)
            let beforeIndex = amount.index(before: index)
            let afterIndex = amount.index(after: index)
            if !amount[index].isNumber {
                // Avoid decimal separator or grouping separator being first character of the new line
                if beforeIndex == amount.startIndex {
                    index = afterIndex
                } else {
                    index = beforeIndex
                }
            }
            amount.insert("\u{200B}", at: index)
        }
        let attributedAmount = NSMutableAttributedString(string: amount, attributes: [
            .font: UIFontMetrics.default.scaledFont(for: .condensed(size: 34)),
            .foregroundColor: R.color.text()!,
        ])
        let attributedSymbol = NSAttributedString(string: "\u{2060} \u{2060}\(token.symbol)", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: R.color.text()!,
        ])
        attributedAmount.append(attributedSymbol)
        amountLabel.attributedText = attributedAmount
    }
    
    func showActionView() {
        showActionViewConstraint.priority = .defaultHigh
        hideActionViewConstraint.priority = .defaultLow
    }
    
    func hideActionView() {
        showActionViewConstraint.priority = .defaultLow
        hideActionViewConstraint.priority = .defaultHigh
    }
    
    @objc private func revealOutputs(_ sender: Any) {
        delegate?.tokenBalanceCellWantsToRevealOutputs(self)
    }
    
}
