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
        let amount: String
        if token.decimalBalance == 0 {
            amount = zeroWith2Fractions
            valueLabel.text = "≈ " + Currency.current.symbol + zeroWith2Fractions
        } else {
            amount = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            valueLabel.text = token.estimatedFiatMoneyBalance
        }
        amountLabel.attributedText = AttributedAmount.attributedString(amount: amount, symbol: token.symbol)
    }
    
    func reloadData(web3Token token: Web3Token) {
        iconView.setIcon(web3Token: token)
        let amount: String
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
        amountLabel.attributedText = AttributedAmount.attributedString(amount: amount, symbol: token.symbol)
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
